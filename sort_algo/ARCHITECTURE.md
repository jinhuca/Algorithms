# sort_algo — architecture

A learning and research hub for **sorting algorithms and data structures**: a clean,
generic C++ **core** library, plus a Qt/QML app — **Sort Algorithm Studio** — that
animates the algorithms step by step and benchmarks them. It mirrors the sibling
**Graph Algorithm Studio** (`../graph_algo`) architecture, substituting the graph
domain for sorting.

## Guiding principles

1. **Core is pure, app is presentation.** The core sorts; it knows nothing about Qt,
   colours, or bar positions. The app owns all of that. Either can evolve
   independently, and the core is usable on its own (tests, CLIs, research code).
2. **One instrumentation hook, two uses.** Every algorithm takes an optional `tracer`
   callback and emits a stream of `step`s. With no tracer it's a plain, fast sort;
   with one, a UI or a test observes the exact same run — the Visualizer animates it,
   the Analyzer counts operations.
3. **Generic and modern.** Templated on the element type with a `Compare`, constrained
   by a C++20 `concept` (`sa::sortable`), C++20 modules as the source of truth.
4. **Readable first.** This is a teaching hub: implementations favour clarity and each
   is documented; the trace events double as a narration of how the algorithm works.

## Repository layout

```
sort_algo/
├─ core/                     generic C++ core (no Qt)
│  ├─ modules/               C++20 module sources (.ixx) — SOURCE OF TRUTH (MSVC/VS2026)
│  │  ├─ seq/                sa.seq (index + sa::sortable concept) · sa.trace (step/tracer)
│  │  ├─ simple_sorts/       bubble · selection · insertion · cocktail · cycle
│  │  ├─ gen/                sa.gen — array distribution generators
│  │  ├─ bench/              sa.bench — timing harness + op-counters
│  │  └─ tests/              module-import smoke test (sort_algo.slnx)
│  ├─ include/sa/            GENERATED header twins (consumed by Qt/MinGW + CTest)
│  ├─ tests/                 dependency-free CTest checks (header-based)
│  ├─ CMakeLists.txt         INTERFACE target  sa::core  + .hpp↔.ixx sync guard
│  └─ sort_algo.slnx       MSVC solution (builds the .ixx modules)
├─ studio/                   Qt 6 / QML app (opt-in build)
├─ scripts/gen_sa_hpp.py     regenerates include/sa/*.hpp from modules/*.ixx
├─ CMakeLists.txt            top-level: always builds core; app optional
└─ ARCHITECTURE.md           this file
```

## Core

### Sequence + concept (`sa::seq`)

Sorting operates on a 1-D, index-addressable range. `sa::index` / `sa::nil` name a
position (mirroring `ga::vertex` / `ga::nil`). The generic-programming contract is the
concept `sa::sortable<R>` — a random-access range of `std::totally_ordered` elements —
and every algorithm is `template <class T, class Compare = sa::less>`, so it sorts any
orderable type (numbers, strings, …) with any strict-weak-ordering comparator.

### Instrumentation (`sa::trace`)

The linchpin between core and app. A sort looks like:

```cpp
template <class T, class Compare = less>
void bubble_sort(std::vector<T>& a, Compare cmp = {}, const tracer& trace = ignore);
```

As it runs it emits `step{ kind, i, j, value, note }` values via `trace`:

| event          | meaning (visual mapping)                                   |
|----------------|------------------------------------------------------------|
| `compare`      | comparing a[i] vs a[j] → flash both bars                   |
| `swap`         | a[i] ↔ a[j] exchanged → swap-colour both                  |
| `overwrite`    | a[i] written with `value` (shifts) → write-colour the bar |
| `read`         | a[i] probed (cycle sort) → highlight                      |
| `cursor`       | a[i] is the current key / min pointer                     |
| `mark_sorted`  | a[i] reached its final position → settled colour          |
| `pass_boundary`| one pass/phase completed → narration                      |
| `message`      | free-form narration                                       |

`step` is element-agnostic (indices + a `double value` for write heights), so one
`tracer` type serves every sort.

### Algorithm catalogue

Each sort is a C++20 module with a generated `.hpp` twin + trace events + tests, and
the app groups them by **complexity category**:

- **O(n²)** — `core/modules/simple_sorts/`: **Bubble**, **Selection**, **Insertion**,
  **Cocktail**, **Cycle**.
- **O(n log n)** — `core/modules/efficient_sorts/`: **Merge** (stable, O(n) space),
  **Quick** (in-place, O(n²) worst), **Heap** (in-place, O(1) space).
- **Advanced** — `core/modules/advanced_sorts/`: **Shell** (gapped insertion, ~O(n log²n),
  in-place), **Radix** (LSD base-256, non-comparison, O(n·k), order-preserving bit key),
  **Counting** (non-comparison, O(n+k), stable), and **Bucket** (distribution, O(n+k)
  average / O(n²) worst). The non-comparison/distribution sorts are ascending-only (no
  comparator) and arithmetic-keyed, but correctly handle negatives and fractional values.

The controllers expose `categories` + `algorithmsIn(category)`, which drive the
Visualizer's Category→Algorithm pickers and the Analyzer's grouped checkbox list.
Later phases can add more (tim, intro, counting, bucket).

### Benchmark foundation (`sa::gen`, `sa::bench`)

- **`sa::gen`** — seeded, reproducible array generators: `random`, `sorted`,
  `reversed`, `nearly_sorted`, `few_unique`, `gaussian`. The input *distribution* is
  what makes a simple sort fast or slow, so each shape is its own generator.
- **`sa::bench`** — a timing harness (`time_it` → min/median/mean/stddev,
  `do_not_optimize`) and a counting `tracer` (`count_into`) tallying
  comparisons / swaps / writes.

### The module / header twin

The `.ixx` under `core/modules/` is the single source of truth (built by the MSVC
solution with `/std:c++20` + modules). `scripts/gen_sa_hpp.py` mechanically mirrors
each into `core/include/sa/**.hpp` so the Qt/MinGW app and the CTest checks use the
exact same code without needing module support. The CMake build runs the script's
`--check` mode and fails if any header is stale.

## App — Sort Algorithm Studio

A Qt 6 / QML desktop app: a splash → Home landing page routes to one of three
workspaces (a `page` property in `Main.qml` swaps the body; the frameless `TitleBar`
is mode-aware). Generic UI tokens + controls come from the shared **UiKit**
(`../UI_repo`); sort-specific colours live in the app's `Theme` singleton.

- **Visualizer** (`VisualizerController` + `VisualizerPage.qml`) — generate an array,
  pick a sort, and watch it run. The controller runs the core algorithm with a
  recording tracer into a step timeline, then plays it forward/back/seek, mapping each
  step to per-bar visual state. Three views bind the same model: **bars**, **dots**
  (scatter), and **colour strip** (hue = value). Running = replaying a precomputed
  trace, so stepping backward is trivial.
- **Analyzer** (`AnalyzerController` + `AnalyzerPage.qml`) — a **headless** benchmark
  workspace. It sweeps the chosen sorts over a list of sizes for one input
  distribution on a worker thread (progress + cancel), timing each run **without** a
  tracer (pure computation) via `sa::bench`, plus a separate untimed counted run for
  comparison/swap totals. Results stream into a table and a time-vs-N scaling chart,
  and export to CSV.
- **Knowledge** (`KnowledgePage.qml` + `KnowledgeContent.qml`) — a curated, searchable
  reference: one article per sort (concept, stability, in-place, best/avg/worst
  complexity, the real `.ixx` path) with deep-link buttons into the Visualizer /
  Analyzer.
- **Stability** (`StabilityController` + `StabilityPage.qml`) — sorts `(key, origin)`
  elements with a key-only comparator and shows input vs result coloured by original
  position, with a stable/not-stable verdict.
- **Race** (`RaceController` + `RacePage.qml`) — records several algorithms' traces on
  one shared array and replays all lanes in lockstep (one operation per tick), so the
  fewest-operations sort finishes first; each lane is a `BarModel` rendered with the
  shared `SortView`.

## Build

- **Core**: header-only `INTERFACE` target `sa::core`; `BUILD_TESTING` adds the CTest
  checks. `cmake -S . -B build && cmake --build build && ctest --test-dir build`.
- **App**: opt in with `-DSORT_ALGO_BUILD_APP=ON` (needs Qt 6 + the sibling UiKit).
- **Modules (MSVC)**: open `core/sort_algo.slnx` in Visual Studio 2026 to build the
  `.ixx` modules directly; after editing a `.ixx`, run `py -I scripts/gen_sa_hpp.py`
  to refresh the header twins.
