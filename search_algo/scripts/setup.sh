#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# search_algo — one-shot setup / build script.
#
# Auto-detects the toolchain, regenerates the generated header twins, then
# configures + builds the portable se::core library and runs its CTest suite.
# With --app it also configures + builds the Qt 6 / QML "Search Algorithm
# Studio" app (needs Qt 6 + the sibling UiKit at ../UI_repo).
#
# Designed for Git Bash on Windows with the Qt MinGW toolchain, but every tool
# location can be overridden with an environment variable (see below). It only
# builds; it installs nothing.
#
# Usage:
#   scripts/setup.sh [options]
#
# Options:
#   --app            also configure + build the Qt/QML app (build-app/)
#   --app-only       build only the app (skip the core build + tests)
#   --no-tests       skip running ctest after the core build
#   --headers-only   just (re)generate + check the header twins, then exit
#   --clean          delete the build directories first
#   --debug          CMAKE_BUILD_TYPE=Debug   (default: Release)
#   -h, --help       show this help
#
# Environment overrides (all optional — auto-detected when unset):
#   PYTHON     python interpreter for the header codegen (e.g. py, python3)
#   MINGW_DIR  MinGW toolchain dir containing bin/g++.exe
#   NINJA_DIR  directory containing ninja(.exe)
#   QT_DIR     Qt kit prefix (…/mingw_64) — needed for --app
#   UI_REPO    path to the shared UiKit repo (default: ../UI_repo)
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIG="Release"
BUILD_CORE=1
BUILD_APP=0
RUN_TESTS=1
HEADERS_ONLY=0
CLEAN=0
BUILD_DIR="$ROOT/build"
APP_BUILD_DIR="$ROOT/build-app"

note()  { printf '\033[36m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[33mwarning:\033[0m %s\n' "$*" >&2; }
die()   { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

usage() { sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --app)          BUILD_APP=1 ;;
    --app-only)     BUILD_APP=1; BUILD_CORE=0 ;;
    --no-tests)     RUN_TESTS=0 ;;
    --headers-only) HEADERS_ONLY=1 ;;
    --clean)        CLEAN=1 ;;
    --debug)        CONFIG="Debug" ;;
    --release)      CONFIG="Release" ;;
    -h|--help)      usage; exit 0 ;;
    *)              die "unknown option: $1  (try --help)" ;;
  esac
  shift
done

# ---- detect a working Python interpreter (for the header codegen) ----------
# Bare python/python3 on Windows may be the Microsoft Store alias stub, which
# exits nonzero; probe each candidate with -I before trusting it.
detect_python() {
  local c
  for c in "${PYTHON:-}" py python3 python; do
    [ -z "$c" ] && continue
    if command -v "$c" >/dev/null 2>&1 && "$c" -I -c "import sys" >/dev/null 2>&1; then
      echo "$c"; return 0
    fi
  done
  local p
  for p in "${LOCALAPPDATA:-/nonexistent}"/Programs/Python/Python*/python.exe \
           /c/Users/*/AppData/Local/Programs/Python/Python*/python.exe; do
    [ -x "$p" ] && { echo "$p"; return 0; }
  done
  return 1
}

newest() { ls -d $1 2>/dev/null | sort -V | tail -1; }   # highest-version match of a glob

PY="$(detect_python || true)"
command -v cmake >/dev/null 2>&1 || die "cmake not found on PATH"

MINGW_DIR="${MINGW_DIR:-$(newest '/c/Qt/Tools/mingw*_64')}"
[ -n "$MINGW_DIR" ] && [ -x "$MINGW_DIR/bin/g++.exe" ] || MINGW_DIR=""
NINJA_DIR="${NINJA_DIR:-}"
if [ -z "$NINJA_DIR" ]; then
  if command -v ninja >/dev/null 2>&1; then NINJA_DIR="$(dirname "$(command -v ninja)")"
  elif [ -x /c/Qt/Tools/Ninja/ninja.exe ]; then NINJA_DIR=/c/Qt/Tools/Ninja; fi
fi
QT_DIR="${QT_DIR:-}"
if [ -z "$QT_DIR" ]; then
  for d in $(newest '/c/Qt/6.*/mingw_64'); do [ -x "$d/bin/qmake.exe" ] && QT_DIR="$d"; done
fi
UI_REPO="${UI_REPO:-$ROOT/../UI_repo}"

# A Ninja + MinGW pair lets us build without Visual Studio; otherwise let CMake
# pick its default generator.
USE_NINJA=0
if [ -n "$NINJA_DIR" ] && [ -n "$MINGW_DIR" ]; then USE_NINJA=1; fi

note "Toolchain"
printf '    cmake   : %s\n' "$(command -v cmake)"
printf '    python  : %s\n' "${PY:-<none — header sync check will be skipped>}"
printf '    mingw   : %s\n' "${MINGW_DIR:-<none — CMake default generator>}"
printf '    ninja   : %s\n' "${NINJA_DIR:-<none>}"
printf '    qt      : %s\n' "${QT_DIR:-<none — needed only for --app>}"
printf '    config  : %s\n' "$CONFIG"

if [ "$CLEAN" = 1 ]; then
  note "Cleaning build directories"
  rm -rf "$BUILD_DIR" "$APP_BUILD_DIR"
fi

# ---- regenerate + verify the generated header twins ------------------------
if [ -n "$PY" ]; then
  note "Regenerating core/include/se/*.hpp from the .ixx modules"
  "$PY" -I scripts/gen_se_hpp.py
  "$PY" -I scripts/gen_se_hpp.py --check
else
  warn "no working Python interpreter found — skipping header regen (set PYTHON=...)"
fi
[ "$HEADERS_ONLY" = 1 ] && { note "Done (headers only)."; exit 0; }

# ---- core: configure + build + test ----------------------------------------
if [ "$BUILD_CORE" = 1 ]; then
  cfg=(-S "$ROOT" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE="$CONFIG")
  if [ "$USE_NINJA" = 1 ]; then
    export PATH="$MINGW_DIR/bin:$NINJA_DIR:$PATH"
    cfg+=(-G Ninja -DCMAKE_CXX_COMPILER=g++)
  fi
  note "Configuring core -> $BUILD_DIR"
  cmake "${cfg[@]}"
  note "Building core"
  cmake --build "$BUILD_DIR"
  if [ "$RUN_TESTS" = 1 ]; then
    note "Running ctest"
    ctest --test-dir "$BUILD_DIR" --output-on-failure
  fi
fi

# ---- app: configure + build ------------------------------------------------
if [ "$BUILD_APP" = 1 ]; then
  [ -n "$QT_DIR" ] || die "Qt not found — set QT_DIR=<Qt>/mingw_64 to build the app"
  [ "$USE_NINJA" = 1 ] || die "the app build needs Ninja + MinGW (set NINJA_DIR / MINGW_DIR)"
  [ -f "$UI_REPO/CMakeLists.txt" ] || warn "UiKit not found at $UI_REPO — set UI_REPO=<path> (pass as -DSE_UI_REPO to CMake)"
  export PATH="$QT_DIR/bin:$MINGW_DIR/bin:$NINJA_DIR:$PATH"
  note "Configuring app -> $APP_BUILD_DIR"
  cmake -S "$ROOT" -B "$APP_BUILD_DIR" -G Ninja -DCMAKE_BUILD_TYPE="$CONFIG" \
        -DCMAKE_PREFIX_PATH="$QT_DIR" -DCMAKE_CXX_COMPILER=g++ \
        -DSEARCH_ALGO_BUILD_APP=ON -DSE_UI_REPO="$UI_REPO"
  note "Building app"
  cmake --build "$APP_BUILD_DIR"
  note "App built: $APP_BUILD_DIR/studio/search_algorithm_studio.exe"
fi

note "Setup complete."
