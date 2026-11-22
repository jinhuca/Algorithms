#!/usr/bin/env python3
"""Generate the header-only twins (core/include/sa/**/*.hpp) from the C++20 module
sources (core/modules/**/*.ixx).

The .ixx module files (under core/modules/, built by the MSVC solution
sort_algo.slnx) are the single source of truth for the sa sort core. The .hpp
mirror them under core/include/sa/ so the Qt/MinGW app and the (module-less) tests
can use the exact same code without C++20 modules / `import std`, which that
toolchain can't rely on.

The module tree mirrors the header tree: core/modules/<path>.ixx generates
core/include/sa/<path>.hpp (e.g. modules/seq/trace.ixx -> include/sa/seq/trace.hpp,
modules/simple_sorts/bubble.ixx -> include/sa/simple_sorts/bubble.hpp).

Do NOT edit the .hpp by hand -- edit the .ixx and run this script. The transform is
mechanical, per file: drop the `module;` fragment marker and the `export module
sa....;` declaration, turn `import sa....;` into the matching `#include "...hpp"`,
strip a leading `export ` (so `export namespace sa` -> `namespace sa`), and prepend
the generated-header banner.

Usage:
  py -I scripts/gen_sa_hpp.py           # (re)generate every core/include/sa/*.hpp
  py -I scripts/gen_sa_hpp.py --check   # exit 1 if any .hpp is stale (CI / build)
"""
import os
import re
import sys
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
MODULES = ROOT / "core" / "modules"          # .ixx source of truth (MSVC)
SA = ROOT / "core" / "include" / "sa"        # generated .hpp output root

# Prepended to every generated header. {name} is the source .ixx file name.
BANNER = """\
#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of {name} (the C++20 module), produced by
// scripts/gen_sa_hpp.py. The .ixx is the source of truth: edit it and re-run
//   py -I scripts/gen_sa_hpp.py
// This header lets the Qt/MinGW app and the tests use the sa core without
// C++20 modules / `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "sa core requires a C++20 compiler (GCC >= 11)."
#endif
"""

_EXPORT_PREFIX = re.compile(r"^(\s*)export\s+")
# `export module sa.seq;` / `export module sa.simple_sorts.bubble;` (captures the name).
_MODULE_DECL = re.compile(r"^\s*export\s+module\s+([\w.]+)\s*;\s*$")
# `import sa.seq;` or `export import sa.seq;` (an intra-project sa.* module).
_IMPORT = re.compile(r"^\s*(?:export\s+)?import\s+([\w.]+)\s*;\s*$")


def ixx_files():
    return sorted(MODULES.rglob("*.ixx"))


def hpp_for(ixx: pathlib.Path) -> pathlib.Path:
    """The generated header for a module: same subpath under include/sa/."""
    return (SA / ixx.relative_to(MODULES)).with_suffix(".hpp")


def module_headers():
    """Map each module's full name to its generated header path, relative to the
    sa/ root (e.g. 'sa.seq' -> 'seq/seq.hpp',
    'sa.simple_sorts.bubble' -> 'simple_sorts/bubble.hpp')."""
    names = {}
    for f in ixx_files():
        rel = hpp_for(f).relative_to(SA).as_posix()
        for line in f.read_text(encoding="utf-8").splitlines():
            mo = _MODULE_DECL.match(line)
            if mo:
                names[mo.group(1)] = rel
                break
    return names


def transform(ixx: pathlib.Path, names: dict) -> str:
    """Turn one module source into the equivalent header text (LF line endings)."""
    cur_dir = hpp_for(ixx).parent
    body = []
    for line in ixx.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped == "module;":
            continue                                  # global-module-fragment marker
        if _MODULE_DECL.match(line):
            continue                                  # module declaration: no header form
        mo = _IMPORT.match(line)
        if mo and mo.group(1) in names:
            target = SA / names[mo.group(1)]          # sibling sa.* module -> its header
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
                f"       Regenerate with:  py -I scripts/gen_sa_hpp.py",
                file=sys.stderr,
            )
            return 1
        print("ok: all core/include/sa/*.hpp are in sync with their .ixx")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
