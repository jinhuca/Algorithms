#!/usr/bin/env bash
#
# clean-builds.sh — remove all CMake/Qt/MSVC build output under Algorithms
# (parent repo + every submodule). Source files are never touched.
#
# Usage:
#   scripts/clean-builds.sh            # delete build output
#   scripts/clean-builds.sh --dry-run  # show what would be deleted, delete nothing
#   scripts/clean-builds.sh -n         # same as --dry-run
#
set -euo pipefail

DRY_RUN=0
case "${1:-}" in
  -n|--dry-run) DRY_RUN=1 ;;
  "") ;;
  *) echo "Unknown option: $1" >&2; echo "Usage: $0 [--dry-run|-n]" >&2; exit 2 ;;
esac

# Run from the repo root regardless of where the script is called from.
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
echo "Scanning for build output under: $ROOT"
[ "$DRY_RUN" -eq 1 ] && echo "(dry run — nothing will be deleted)"

# Build-output directory names (match the .gitignore patterns).
# -prune: match the dir but do not descend into it. Never match inside .git.
mapfile -t DIRS < <(
  find . -type d -name '.git' -prune -o -type d \( \
      -name 'build'          -o \
      -name 'build-*'        -o \
      -name 'out'            -o \
      -name 'cmake-build-*'  -o \
      -name 'CMakeFiles'     -o \
      -name '.vs'            -o \
      -name 'x64'            -o \
      -name 'Win32'          -o \
      -name 'Debug'          -o \
      -name 'Release' \
    \) -prune -print | sort
)

# Stray CMake-generated config files sitting outside a build dir.
mapfile -t FILES < <(
  find . -type d -name '.git' -prune -o -type f \( \
      -name 'CMakeCache.txt'      -o \
      -name 'cmake_install.cmake' -o \
      -name 'CTestTestfile.cmake' \
    \) -print | sort
)

if [ "${#DIRS[@]}" -eq 0 ] && [ "${#FILES[@]}" -eq 0 ]; then
  echo "Nothing to clean — already clean."
  exit 0
fi

for d in "${DIRS[@]}";  do echo "  dir   $d"; done
for f in "${FILES[@]}"; do echo "  file  $f"; done

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry run complete. Re-run without --dry-run to delete."
  exit 0
fi

for d in "${DIRS[@]}";  do rm -rf  "$d"; done
for f in "${FILES[@]}"; do rm -f   "$f"; done
echo "Done — build output removed."
