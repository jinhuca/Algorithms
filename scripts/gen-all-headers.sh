#!/usr/bin/env bash
#
# gen-all-headers.sh — regenerate (or --check) every core's header-only .hpp twins
# from its .ixx modules, across all studios, using the one unified generator
# scripts/gen_hpp.py.
#
# Usage:
#   scripts/gen-all-headers.sh           # (re)generate every core/include/<ns>/*.hpp
#   scripts/gen-all-headers.sh --check   # CI / pre-commit: fail if any twin is stale
#
set -euo pipefail

cd "$(dirname "$0")/.."                    # repo root, regardless of where it's called
ROOT="$(pwd)"

# Pick a working Python (py -3 on Windows, else python3/python).
if command -v py >/dev/null 2>&1; then PY="py -3";
elif command -v python3 >/dev/null 2>&1; then PY="python3";
else PY="python"; fi

# project dir : namespace
PROJECTS=(
  "search_algo:se"
  "sort_algo:sa"
  "tree_algo:tr"
  "graph_algo:ga"
  "foundation_algo:fo"
  "combinatorics_algo:cb"
  "numerics_algo:nu"
)

rc=0
for entry in "${PROJECTS[@]}"; do
  proj="${entry%%:*}"; ns="${entry##*:}"
  [ -d "$ROOT/$proj/core/modules" ] || { echo "skip $proj (no core/modules)"; continue; }
  echo "== $proj (ns $ns) =="
  if ! $PY -I scripts/gen_hpp.py --project "$proj" --ns "$ns" "$@"; then
    rc=1
  fi
done
exit $rc
