# Search Algorithm Studio

A learning + research hub for **search algorithms**, built with a pure generic C++20
**core** and (phase 2) a **Qt 6 / QML** desktop app. Educate (watch a search narrow in
on its target step by step) and research (benchmark searches across input distributions
and sizes). Sibling to [Sort Algorithm Studio](../sort_algo).

Eight searches across two categories, each implemented as a C++20 module:

- **Sequential** (no ordering needed) — Linear, Sentinel
- **Sorted** (require a sorted array) — Binary, Ternary, Jump, Exponential,
  Interpolation, Fibonacci

Every search shares one signature — it takes the array, the target, an optional
`Compare` (so a descending array works with `std::greater`), and an optional `tracer` —
and returns the found index or `se::nil`:

```cpp
se::index i = se::binary_search(a, target);          // plain, fast
se::index j = se::binary_search(a, target, cmp, tr); // same run, observed step by step
```

## Status

- **Core** (`se::core`) — implemented and tested: the eight searches, the `se::seq`
  concept + `se::trace` instrumentation, and the `se::gen` / `se::bench` benchmark
  foundation. The CTest suite passes (incl. a 500-trial fuzz across all algorithms).
- **App** (`studio/`) — implemented: a Qt 6 / QML desktop app with Home + three
  workspaces (Visualizer, Analyzer, Knowledge), mirroring Sort Algorithm Studio. See
  [studio/README.md](studio/README.md).

## Workspaces

- **Visualizer** — pick an array shape, size and a target (a preset position or a custom
  value), choose a search, and play it forward / backward / step / seek. A probe cursor,
  the sliding lo/hi window and the discarded regions are colour-coded, with a synced
  pseudocode panel and a live probe / window / step readout.
- **Analyzer** — a headless sweep over sizes for one distribution and target mode:
  deterministic **probe counts** and measured **ns/search**, streamed into a table and a
  metric-vs-N scaling chart with a Big-O overlay (O(log n) / O(√n) / O(n)), plus CSV export.
- **Knowledge** — a searchable reference: how each search works, its pre-conditions
  (sorted vs any order), best / average / worst complexity, and deep links into the
  Visualizer / Analyzer.

## Build

### Quick start (setup script)

On Windows with Git Bash + the Qt MinGW toolchain, one script auto-detects the toolchain
(Python, CMake, MinGW, Ninja, Qt), regenerates the header twins, and builds + tests:

```sh
scripts/setup.sh            # build se::core + run the CTest suite
scripts/setup.sh --app      # also build the Qt/QML app (build-app/)
scripts/setup.sh --help     # all options (--clean, --debug, --headers-only, …)
```

Every tool location can be overridden with an env var (`QT_DIR`, `MINGW_DIR`, `NINJA_DIR`,
`PYTHON`, `UI_REPO`). The steps below are the same thing done by hand.

### Core + tests (no Qt)

```sh
cmake -S . -B build && cmake --build build && ctest --test-dir build
```

The CTest suite is `se_test_core` (fixed cases, present/absent targets, custom
comparator, strings, concept checks), `se_test_gen_bench` (generators + timing harness +
probe counters), and `se_test_fuzz` (every search vs a reference over hundreds of random
inputs, present and absent targets, with duplicates/negatives/fractions). The build also
fails if any generated `include/se/*.hpp` is stale vs its `.ixx`.
[CI](.github/workflows/ci.yml) runs all of this on Linux, Windows and macOS.

### The app

Needs Qt 6 (6.5+) and the shared [UiKit](../UI_repo) sibling module.

```sh
cmake -S . -B build-app -G Ninja \
  -DCMAKE_PREFIX_PATH=<Qt>/mingw_64 \
  -DSEARCH_ALGO_BUILD_APP=ON
cmake --build build-app
./build-app/studio/search_algorithm_studio.exe
```

Override the UiKit location with `-DSE_UI_REPO=<path>` if it isn't at `../UI_repo`.

### C++20 modules (MSVC / Visual Studio 2026)

The `core/modules/**/*.ixx` are the source of truth. Open `core/search_algo.slnx` to
build them directly (phase-2 solution). After editing a `.ixx`, regenerate the header
twins the CMake build and tests consume:

```sh
py -I scripts/gen_se_hpp.py          # regenerate core/include/se/*.hpp
py -I scripts/gen_se_hpp.py --check  # CI: fail if any header is stale
```

## Platform

The **core** is portable C++20 and is exercised by CI on Linux, Windows and macOS. The
**app** will build with Qt 6 on any platform. See [ARCHITECTURE.md](ARCHITECTURE.md) for
the full design.
