#!/usr/bin/env python3
"""Generate the header-only twins (core/include/se/**/*.hpp) from the C++20 module
sources (core/modules/**/*.ixx).

The .ixx module files (under core/modules/, built by the MSVC solution
search_algo.slnx) are the single source of truth for the se search core. The .hpp
mirror them under core/include/se/ so the Qt/MinGW app and the (module-less) tests can
use the exact same code without C++20 modules / `import std`, which that toolchain
can't rely on.

The module tree mirrors the header tree: core/modules/<path>.ixx generates
core/include/se/<path>.hpp (e.g. modules/seq/trace.ixx -> include/se/seq/trace.hpp,
modules/sorted_searches/binary.ixx -> include/se/sorted_searches/binary.hpp).

Do NOT edit the .hpp by hand -- edit the .ixx and run this script. The transform is
mechanical, per file: drop the `module;` fragment marker and the `export module
se....;` declaration, turn `import se....;` into the matching `#include "...hpp"`,
strip a leading `export ` (so `export namespace se` -> `namespace se`), and prepend
the generated-header banner.

Usage:
  py -I scripts/gen_se_hpp.py           # (re)generate every core/include/se/*.hpp
  py -I scripts/gen_se_hpp.py --check   # exit 1 if any .hpp is stale (CI / build)
"""
import os
import re
import sys
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
MODULES = ROOT / "core" / "modules"          # .ixx source of truth (MSVC)
SE = ROOT / "core" / "include" / "se"        # generated .hpp output root

# Prepended to every generated header. {name} is the source .ixx file name.
BANNER = """\
#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of {name} (the C++20 module), produced by
// scripts/gen_se_hpp.py. The .ixx is the source of truth: edit it and re-run
//   py -I scripts/gen_se_hpp.py
// This header lets the Qt/MinGW app and the tests use the se core without
// C++20 modules / `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "se core requires a C++20 compiler (GCC >= 11)."
#endif
"""

_EXPORT_PREFIX = re.compile(r"^(\s*)export\s+")
# `export module se.seq;` / `export module se.sorted_searches.binary;` (captures the name).
_MODULE_DECL = re.compile(r"^\s*export\s+module\s+([\w.]+)\s*;\s*$")
# `import se.seq;` or `export import se.seq;` (an intra-project se.* module).
_IMPORT = re.compile(r"^\s*(?:export\s+)?import\s+([\w.]+)\s*;\s*$")


def ixx_files():
    return sorted(MODULES.rglob("*.ixx"))


def hpp_for(ixx: pathlib.Path) -> pathlib.Path:
    """The generated header for a module: same subpath under include/se/."""
    return (SE / ixx.relative_to(MODULES)).with_suffix(".hpp")


def module_headers():
    """Map each module's full name to its generated header path, relative to the
    se/ root (e.g. 'se.seq' -> 'seq/seq.hpp',
    'se.sorted_searches.binary' -> 'sorted_searches/binary.hpp')."""
    names = {}
    for f in ixx_files():
        rel = hpp_for(f).relative_to(SE).as_posix()
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
            target = SE / names[mo.group(1)]          # sibling se.* module -> its header
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
                f"       Regenerate with:  py -I scripts/gen_se_hpp.py",
                file=sys.stderr,
            )
            return 1
        print("ok: all core/include/se/*.hpp are in sync with their .ixx")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
