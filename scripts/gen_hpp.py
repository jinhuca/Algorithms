#!/usr/bin/env python3
"""Generate the header-only twins (<project>/core/include/<ns>/**/*.hpp) from the
C++20 module sources (<project>/core/modules/**/*.ixx), for ANY studio core in the
monorepo.

This is the single, unified generator for every core (sa / se / ga / fo / cb / nu).
The per-project `scripts/gen_<ns>_hpp.py` are thin shims that call this with the right
`--project` / `--ns`; `scripts/gen-all-headers.{sh,cmd}` run it across all projects.

The .ixx module files (under <project>/core/modules/, built by the project's MSVC
solution) are the single source of truth for a core. The .hpp mirror them under
<project>/core/include/<ns>/ so the Qt/MinGW app and the (module-less) tests can use
the exact same code without C++20 modules / `import std`, which that toolchain can't
rely on.

The module tree mirrors the header tree: core/modules/<path>.ixx generates
core/include/<ns>/<path>.hpp (e.g. modules/seq/trace.ixx -> include/<ns>/seq/trace.hpp).

Do NOT edit the .hpp by hand -- edit the .ixx and re-run this script. The transform is
mechanical, per file: drop the `module;` fragment marker and the `export module ...;`
declaration, turn an intra-project `import <ns>....;` into the matching `#include
"...hpp"`, strip a leading `export ` (so `export namespace` -> `namespace`), and
prepend the generated-header banner.

`import std;` has no header form (the twin targets toolchains without a std module).
This script expands it to the curated STD_INCLUDES superset below, so a module can just
write `import std;` for MSVC and the header still compiles under MinGW/Qt. To pin a
minimal, exact include set for one module instead, list `//#include <...>` hints next
to `import std;` -- those win over the curated set.

Usage:
  py -I scripts/gen_hpp.py --project sort_algo --ns sa            # (re)generate
  py -I scripts/gen_hpp.py --project sort_algo --ns sa --check    # CI: fail if stale
"""
import argparse
import os
import re
import sys
import pathlib

# Curated superset of the standard headers the cores use -- the union across every
# studio core, so one list serves them all. `import std;` (without `//#include` hints)
# expands to this. Add to it if a core starts using a facility whose header isn't here
# (the MinGW/Qt build names the missing one).
STD_INCLUDES = [
    "<algorithm>", "<bit>", "<chrono>", "<cmath>", "<compare>", "<concepts>",
    "<cstddef>", "<cstdint>", "<functional>", "<iterator>", "<limits>", "<map>", "<numeric>",
    "<queue>", "<random>", "<ranges>", "<string>", "<tuple>", "<type_traits>",
    "<unordered_set>", "<utility>", "<vector>",
]

_EXPORT_PREFIX = re.compile(r"^(\s*)export\s+")
# `export module <ns>.seq;` / `export module <ns>.simple_sorts.bubble;` (captures the name).
_MODULE_DECL = re.compile(r"^\s*export\s+module\s+([\w.]+)\s*;\s*$")
# `import <ns>.seq;` or `export import <ns>.seq;` (an intra-project module).
_IMPORT = re.compile(r"^\s*(?:export\s+)?import\s+([\w.]+)\s*;\s*$")
# `import std;` -- the whole standard library; no header form (see the module docstring).
_IMPORT_STD = re.compile(r"^\s*import\s+std\s*;\s*$")
# A commented-out system include, e.g. `//#include <ranges>` -- the header-twin form of
# (part of) `import std;`. Captures the live `#include <...>` directive.
_COMMENTED_SYS_INCLUDE = re.compile(r"^\s*//\s*(#include\s*<[^>]+>)\s*$")


def banner(ixx_name: str, project: str, ns: str) -> str:
    return f"""\
#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of {ixx_name} (the C++20 module), produced by
//   py -I scripts/gen_hpp.py --project {project} --ns {ns}
// The .ixx is the source of truth: edit it and re-run the generator. This header
// lets the Qt/MinGW app and the tests use the {ns} core without C++20 modules /
// `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "{ns} core requires a C++20 compiler (GCC >= 11)."
#endif
"""


def transform(ixx: pathlib.Path, names: dict, out_root: pathlib.Path,
              project: str, ns: str) -> str:
    """Turn one module source into the equivalent header text (LF line endings)."""
    cur_dir = hpp_for(ixx, names_root=out_root, modules_root=names["__modules__"]).parent
    lines = ixx.read_text(encoding="utf-8").splitlines()
    uses_import_std = any(_IMPORT_STD.match(l) for l in lines)
    has_hints = any(_COMMENTED_SYS_INCLUDE.match(l) for l in lines)
    expand_std = uses_import_std and not has_hints
    body = []
    for line in lines:
        stripped = line.strip()
        if stripped == "module;":
            continue                                  # global-module-fragment marker
        if _MODULE_DECL.match(line):
            continue                                  # module declaration: no header form
        if _IMPORT_STD.match(line):
            if expand_std:
                body.extend(f"#include {h}" for h in STD_INCLUDES)
                expand_std = False                    # inject the curated set once
            continue                                  # `import std;` -> #includes (hints or set)
        if uses_import_std:
            mc = _COMMENTED_SYS_INCLUDE.match(line)
            if mc:
                body.append(mc.group(1))              # `//#include <ranges>` -> `#include <ranges>`
                continue
        mo = _IMPORT.match(line)
        if mo and mo.group(1) in names:
            target = out_root / names[mo.group(1)]    # sibling module -> its header
            inc = os.path.relpath(target, cur_dir).replace(os.sep, "/")
            body.append(f'#include "{inc}"')
            continue
        body.append(_EXPORT_PREFIX.sub(r"\1", line, count=1))   # `export namespace` -> `namespace`

    text = "\n".join(body).lstrip("\n")
    text = re.sub(r"\n{3,}", "\n\n", text)                      # collapse blank runs
    return banner(ixx.name, project, ns) + "\n" + text.rstrip("\n") + "\n"


def hpp_for(ixx: pathlib.Path, names_root: pathlib.Path,
            modules_root: pathlib.Path) -> pathlib.Path:
    """The generated header for a module: same subpath under include/<ns>/."""
    return (names_root / ixx.relative_to(modules_root)).with_suffix(".hpp")


def module_headers(ixx_files, modules_root, out_root):
    """Map each module's full name to its generated header path relative to the
    <ns>/ root (e.g. 'sa.seq' -> 'seq/seq.hpp'). Also stashes '__modules__'."""
    names = {"__modules__": modules_root}
    for f in ixx_files:
        rel = hpp_for(f, out_root, modules_root).relative_to(out_root).as_posix()
        for line in f.read_text(encoding="utf-8").splitlines():
            mo = _MODULE_DECL.match(line)
            if mo:
                names[mo.group(1)] = rel
                break
    return names


def _detect_eol(path: pathlib.Path) -> str:
    if path.exists() and b"\r\n" in path.read_bytes():
        return "\r\n"
    return "\n"


def main(argv) -> int:
    ap = argparse.ArgumentParser(description="Generate header-only twins from .ixx modules.")
    ap.add_argument("--project", required=True,
                    help="project dir (contains core/modules and core/include/<ns>)")
    ap.add_argument("--ns", required=True, help="namespace subdir under core/include/")
    ap.add_argument("--check", action="store_true",
                    help="exit 1 if any .hpp is stale instead of writing")
    args = ap.parse_args(argv[1:])

    root = pathlib.Path(args.project).resolve()
    project = root.name
    modules_root = root / "core" / "modules"
    out_root = root / "core" / "include" / args.ns

    files = sorted(modules_root.rglob("*.ixx"))
    if not files:
        print(f"error: no .ixx found under {modules_root}", file=sys.stderr)
        return 2
    names = module_headers(files, modules_root, out_root)

    stale = []
    for ixx in files:
        hpp = hpp_for(ixx, out_root, modules_root)
        expected = transform(ixx, names, out_root, project, args.ns)
        if args.check:
            current = hpp.read_text(encoding="utf-8") if hpp.exists() else ""
            if current.splitlines() != expected.splitlines():
                stale.append(hpp)
        else:
            eol = _detect_eol(ixx)
            hpp.parent.mkdir(parents=True, exist_ok=True)
            with open(hpp, "w", encoding="utf-8", newline="") as f:
                f.write(expected.replace("\n", eol))
            print(f"wrote {hpp.relative_to(root)} from {ixx.relative_to(root)}")

    if args.check:
        if stale:
            rels = "\n       ".join(str(h.relative_to(root)) for h in stale)
            print(
                f"error: these {args.ns} headers are STALE relative to their .ixx:\n       {rels}\n"
                f"       Regenerate with:  py -I scripts/gen_hpp.py --project {project} --ns {args.ns}",
                file=sys.stderr,
            )
            return 1
        print(f"ok: all {args.project}/core/include/{args.ns}/*.hpp are in sync with their .ixx")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
