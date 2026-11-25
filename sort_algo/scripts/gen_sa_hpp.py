#!/usr/bin/env python3
"""Thin shim for the unified monorepo generator.

The real logic now lives in the top-level ../../scripts/gen_hpp.py (one generator for
every studio core). This shim is kept so the documented command and setup.sh still
work unchanged:

  py -I scripts/gen_sa_hpp.py           # regenerate core/include/sa/*.hpp
  py -I scripts/gen_sa_hpp.py --check   # CI: fail if any header is stale

It forwards to:  gen_hpp.py --project sort_algo --ns sa [--check]
"""
import pathlib
import runpy
import sys

HERE = pathlib.Path(__file__).resolve()
PROJECT = HERE.parent.parent                       # sort_algo/
GEN = PROJECT.parent / "scripts" / "gen_hpp.py"    # <monorepo>/scripts/gen_hpp.py
sys.argv = [str(GEN), "--project", str(PROJECT), "--ns", "sa", *sys.argv[1:]]
runpy.run_path(str(GEN), run_name="__main__")
