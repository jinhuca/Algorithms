# Algorithms

A monorepo of **algorithm learning + research studios**. Each project pairs a pure,
generic **C++20 core** with a **Qt 6 / QML desktop app** that both *teaches* (watch an
algorithm run step by step) and *measures* (benchmark across input shapes and sizes).
The three studios share one architecture and one UI design system.

| Project | Namespace | What it covers | Docs |
| --- | --- | --- | --- |
| [search_algo](search_algo/) — Search Algorithm Studio | `se::` | 8 search algorithms | [README](search_algo/README.md) · [ARCHITECTURE](search_algo/ARCHITECTURE.md) |
| [sort_algo](sort_algo/) — Sort Algorithm Studio | `sa::` | 12 sorting algorithms | [README](sort_algo/README.md) · [ARCHITECTURE](sort_algo/ARCHITECTURE.md) |
| [graph_algo](graph_algo/) — Graph Algorithm Studio | `ga::` | graph + 6 graph algorithms | [README](graph_algo/README.md) · [ARCHITECTURE](graph_algo/ARCHITECTURE.md) |
| [UI_repo](UI_repo/) — UiKit | — | shared Qt/QML design system | [README](UI_repo/README.md) |
| [scripts/](scripts/) | — | cross-project build-output cleanup | [README](scripts/README.md) |

## The projects

### search_algo — Search Algorithm Studio
Eight searches in two families. **Sequential** (any order): Linear, Sentinel.
**Sorted** (require a sorted array): Binary, Ternary, Jump, Exponential, Interpolation,
Fibonacci. Every search shares one signature — array, target, optional `Compare`
(so `std::greater` handles a descending array), optional `tracer` — and returns the
found index or `se::nil`.

### sort_algo — Sort Algorithm Studio
Twelve sorts in three categories. **O(n²)**: Bubble, Selection, Insertion, Cocktail,
Cycle. **O(n log n)**: Merge, Quick, Heap. **Advanced / non-comparison**: Shell, Radix
(LSD), Counting, Bucket.

### graph_algo — Graph Algorithm Studio
A generic `ga::graph<W>` plus six algorithms: **BFS**, **DFS**, **Dijkstra**,
**Bellman–Ford**, and the **Kruskal** / **Prim** minimum spanning trees. Each takes an
optional `tracer` so a run can be observed and animated.

## Shared architecture

Every studio follows the same two-layer split:

```
core/     generic C++20 algorithm core — no Qt, portable, CI-tested on Linux/Windows/macOS
studio/   Qt 6 / QML desktop app that visualizes + benchmarks the core (reuses UiKit)
```

**One source, two consumers.** The core is authored once as **C++20 modules**
(`core/modules/**/*.ixx`, the single source of truth, built by the MSVC
`core/*.slnx` solution). Because the Qt/MinGW app and the lightweight test suite
can't rely on C++ modules / `import std`, a small Python generator produces a
**header-only twin** of each module under `core/include/<ns>/**/*.hpp`:

```sh
py -I scripts/gen_<ns>_hpp.py          # regenerate the .hpp twins from the .ixx
py -I scripts/gen_<ns>_hpp.py --check  # CI / pre-commit: fail if a twin is stale
```

The generator strips the module scaffolding and **expands `import std;` into the
equivalent `#include` set** so the twins compile under plain C++20 (GCC ≥ 11 / MinGW).
The CMake build fails if any twin is stale relative to its `.ixx`.

Each algorithm is instrumented with an optional `tracer` callback: with none it's a
plain fast routine; with one, a UI (or a test) observes the exact same run and animates
it step by step.

### The apps

The `search` and `sort` studios share a workspace layout:

- **Visualizer** — pick an input, choose an algorithm, and play it forward / backward /
  step / seek, with colour-coded state and a synced pseudocode panel.
- **Analyzer** — a headless sweep over sizes: operation counts and timings streamed into
  a table and a metric-vs-N scaling chart with a Big-O overlay, plus CSV export.
- **Knowledge** — a searchable reference (how each algorithm works, pre-conditions,
  complexity) with deep links into the other workspaces.
- *(sort only)* **Stability** — shows which sorts preserve the order of equal keys.

`graph_algo`'s studio is a step-by-step **Visualizer** MVP (frontier / current / settled
colouring, result tree, distances). All three apps draw their generic controls and
design tokens from the shared **[UiKit](UI_repo/)** module.

## Build

Each project builds independently from its own directory.

**Core + tests (no Qt):**

```sh
cd <project>                                    # search_algo | sort_algo | graph_algo
cmake -S . -B build && cmake --build build && ctest --test-dir build --output-on-failure
```

Each suite covers fixed cases, concept checks, the generator foundation, and a fuzz
test comparing every algorithm against a reference over hundreds of random inputs.

**The app** (needs Qt 6 ≥ 6.5 and the sibling [UiKit](UI_repo/)):

```sh
cd <project>
cmake -S . -B build-app -G Ninja \
  -DCMAKE_PREFIX_PATH=<Qt>/mingw_64 \
  -D<PROJECT>_BUILD_APP=ON            # SEARCH_ALGO_BUILD_APP / SORT_ALGO_BUILD_APP / GRAPH_ALGO_BUILD_VISUALIZER
cmake --build build-app
```

Override the UiKit location with the project's `*_UI_REPO` cache var if it isn't at
`./UI_repo`. `search_algo` also has a one-shot `scripts/setup.sh` that auto-detects the
toolchain and builds + tests.

**C++20 modules (MSVC / Visual Studio 2026):** open `core/<project>.slnx` to build the
`.ixx` modules directly; the `.ixx` use `import std;` (with `BuildStlModules` enabled).
After editing a `.ixx`, regenerate the header twins with the generator above.

**Clean build output** across every project in one pass:

```sh
./scripts/clean-builds.sh --dry-run   # preview; drop --dry-run to delete
```

## Repository layout

```
Algorithms/
├─ search_algo/   core/ (modules + include twins + tests) · studio/ · scripts/
├─ sort_algo/     core/ (…) · studio/ · scripts/
├─ graph_algo/    core/ (…) · studio/ · scripts/
├─ UI_repo/       UiKit — shared Qt/QML design system (consumed via add_subdirectory)
└─ scripts/       clean-builds.{sh,cmd} — build-output cleanup
```

See each project's `README.md` and `ARCHITECTURE.md` for full detail.
