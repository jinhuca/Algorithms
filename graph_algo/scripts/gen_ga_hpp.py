#!/usr/bin/env python3
"""Generate the header-only twins (core/include/ga/**/*.hpp) from the C++20
module sources (core/modules/**/*.ixx).

The .ixx module files (under core/modules/, built by the MSVC solution
graph_algo.slnx) are the single source of truth for the ga graph core. The .hpp
mirror them under core/include/ga/ so the Qt/MinGW visualizer and the
(module-less) tests can use the exact same code without C++20 modules /
`import std`, which that toolchain can't rely on.

The module tree mirrors the header tree: core/modules/<path>.ixx generates
core/include/ga/<path>.hpp (e.g. modules/graph.ixx -> include/ga/graph.hpp,
modules/algorithms/bfs.ixx -> include/ga/algorithms/bfs.hpp).

Do NOT edit the .hpp by hand -- edit the .ixx and run this script. The transform
is mechanical, per file: drop the `module;` fragment marker and the
`export module ga:...;` declaration, turn `import :part;` into the matching
`#include "...hpp"`, strip a leading `export ` (so `export namespace ga` ->
`namespace ga`), and prepend the generated-header banner.

`import std;` has no header form (the header twin targets toolchains without a std
module). This script expands it to the curated STD_INCLUDES set below, so a module can
just write `import std;` for MSVC and the header still compiles under MinGW/Qt. To pin
a minimal, exact include set for one module instead, list `//#include <...>` hints next
to `import std;` -- those win over the curated set.

Usage:
  py -I scripts/gen_ga_hpp.py           # (re)generate every core/include/ga/*.hpp
  py -I scripts/gen_ga_hpp.py --check   # exit 1 if any .hpp is stale (CI / build)
"""
import os
import re
import sys
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
MODULES = ROOT / "core" / "modules"          # .ixx source of truth (MSVC)
GA = ROOT / "core" / "include" / "ga"        # generated .hpp output root

# Prepended to every generated header. {name} is the source .ixx file name.
BANNER = """\
#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of {name} (the C++20 module), produced by
// scripts/gen_ga_hpp.py. The .ixx is the source of truth: edit it and re-run
//   py -I scripts/gen_ga_hpp.py
// This header lets the Qt/MinGW visualizer and the tests use the ga core
// without C++20 modules / `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "ga core requires a C++20 compiler (GCC >= 11)."
#endif
"""

_EXPORT_PREFIX = re.compile(r"^(\s*)export\s+")
# `export module ga.graph;` / `export module ga.short_paths.dijkstra;` (captures the name).
_MODULE_DECL = re.compile(r"^\s*export\s+module\s+([\w.]+)\s*;\s*$")
# `import ga.graph;` or `export import ga.graph;` (an intra-project ga.* module).
_IMPORT = re.compile(r"^\s*(?:export\s+)?import\s+([\w.]+)\s*;\s*$")
# `import std;` -- the whole standard library; no header form (see module docstring).
_IMPORT_STD = re.compile(r"^\s*import\s+std\s*;\s*$")
# A commented-out system include, e.g. `//#include <ranges>` -- the header-twin form
# of (part of) `import std;`. Captures the live `#include <...>` directive.
_COMMENTED_SYS_INCLUDE = re.compile(r"^\s*//\s*(#include\s*<[^>]+>)\s*$")

# `import std;` names the whole standard library, which a header can't; when a module
# uses `import std;` without explicit `//#include` hints, the twin gets this curated
# superset of the standard headers the cores use. Add to this list if a core starts
# using a facility whose header isn't here (the MinGW/Qt build names the missing one).
STD_INCLUDES = [
    "<algorithm>", "<bit>", "<chrono>", "<cmath>", "<compare>", "<concepts>",
    "<cstddef>", "<cstdint>", "<functional>", "<limits>", "<map>", "<numeric>",
    "<queue>", "<random>", "<ranges>", "<string>", "<tuple>", "<type_traits>",
    "<unordered_set>", "<utility>", "<vector>",
]


def ixx_files():
    return sorted(MODULES.rglob("*.ixx"))


def hpp_for(ixx: pathlib.Path) -> pathlib.Path:
    """The generated header for a module: same subpath under include/ga/."""
    return (GA / ixx.relative_to(MODULES)).with_suffix(".hpp")


def module_headers():
    """Map each module's full name to its generated header path, relative to the
    ga/ root (e.g. 'ga.graph' -> 'graph/graph.hpp',
    'ga.short_paths.dijkstra' -> 'short_paths/dijkstra.hpp')."""
    names = {}
    for f in ixx_files():
        rel = hpp_for(f).relative_to(GA).as_posix()
        for line in f.read_text(encoding="utf-8").splitlines():
            mo = _MODULE_DECL.match(line)
            if mo:
                names[mo.group(1)] = rel
                break
    return names


def transform(ixx: pathlib.Path, names: dict) -> str:
    """Turn one module source into the equivalent header text (LF line endings)."""
    cur_dir = hpp_for(ixx).parent
    lines = ixx.read_text(encoding="utf-8").splitlines()
    uses_import_std = any(_IMPORT_STD.match(l) for l in lines)
    # Explicit `//#include <...>` hints give an exact, minimal include set and win;
    # with none, `import std;` expands to the curated STD_INCLUDES set.
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
            target = GA / names[mo.group(1)]          # sibling ga.* module -> its header
            inc = os.path.relpath(target, cur_dir).replace(os.sep, "/")
            body.append(f'#include "{inc}"')
            continue
        body.append(_EXPORT_PREFIX.sub(r"\1", line, count=1))   # `export namespace` -> `namespace`

    text = "\n".join(body).lstrip("\n")
    text = re.sub(r"\n{3,}", "\n\n", text)                      # collapse blank runs left by
                                                                # dropped module/import lines
    return BANNER.format(name=ixx.name) + "\n" + text.rstrip("\n") + "\n"


def _detect_eol(path: pathlib.Path) -> str:
    if path.exists() and b"\r\n" in path.read_bytes():
        return "\r\n"
    return "\n"


def main(argv) -> int:
    check_only = "--check" in argv[1:]
    files = ixx_files()
    if not files:
        print(f"error: no .ixx found under {MODULES}", file=sys.stderr)
        return 2
    names = module_headers()

    stale = []
    for ixx in files:
        hpp = hpp_for(ixx)
        expected = transform(ixx, names)
        if check_only:
            current = hpp.read_text(encoding="utf-8") if hpp.exists() else ""
            if current.splitlines() != expected.splitlines():
                stale.append(hpp)
        else:
            eol = _detect_eol(ixx)
            hpp.parent.mkdir(parents=True, exist_ok=True)   # new module subdir -> new header dir
            with open(hpp, "w", encoding="utf-8", newline="") as f:
                f.write(expected.replace("\n", eol))
            print(f"wrote {hpp.relative_to(ROOT)} from {ixx.relative_to(ROOT)}")

    if check_only:
        if stale:
            rels = "\n       ".join(str(h.relative_to(ROOT)) for h in stale)
            print(
                f"error: these headers are STALE relative to their .ixx:\n       {rels}\n"
                f"       Regenerate with:  py -I scripts/gen_ga_hpp.py",
                file=sys.stderr,
            )
            return 1
        print("ok: all core/include/ga/*.hpp are in sync with their .ixx")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
