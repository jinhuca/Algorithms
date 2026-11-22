# search_algo — architecture

A learning and research hub for **search algorithms**: a clean, generic C++ **core**
library, plus a Qt/QML app — **Search Algorithm Studio** — that animates the algorithms
step by step and benchmarks them. It mirrors the sibling **Sort Algorithm Studio**
(`../sort_algo`) and **Graph Algorithm Studio** architectures, substituting the search
domain (finding a target in a sequence) for sorting / graphs.

## Guiding principles

1. **Core is pure, app is presentation.** The core searches; it knows nothing about Qt,
   colours, or bar positions. The app owns all of that. Either can evolve independently,
   and the core is usable on its own (tests, CLIs, research code).
2. **One instrumentation hook, two uses.** Every algorithm takes an optional `tracer`
   callback and emits a stream of `step`s. With no tracer it's a plain, fast search;
   with one, a UI or a test observes the exact same run — the Visualizer animates it,
   the Analyzer counts probes.
3. **Generic and modern.** Templated on the element type with a `Compare`, constrained
   by a C++20 `concept` (`se::searchable`), C++20 modules as the source of truth.
4. **Readable first.** This is a teaching hub: implementations favour clarity and each
   is documented; the trace events double as a narration of how the algorithm works.

## Repository layout

```
search_algo/
├─ core/                     generic C++ core (no Qt)
│  ├─ modules/               C++20 module sources (.ixx) — SOURCE OF TRUTH (MSVC/VS2026)
│  │  ├─ seq/                se.seq (index + se::searchable concept) · se.trace (step/tracer)
│  │  ├─ sequential_searches/ linear · sentinel
│  │  ├─ sorted_searches/    binary · ternary · jump · exponential · interpolation · fibonacci
│  │  ├─ gen/                se.gen — array + target generators
│  │  ├─ bench/              se.bench — timing harness + probe-counters
│  │  └─ tests/              module-import smoke test (search_algo.slnx)
│  ├─ include/se/            GENERATED header twins (consumed by Qt/MinGW + CTest)
│  ├─ tests/                 dependency-free CTest checks (header-based)
│  └─ CMakeLists.txt         INTERFACE target  se::core  + .hpp↔.ixx sync guard
├─ studio/                   Qt 6 / QML app (phase 2)
├─ scripts/gen_se_hpp.py     regenerates include/se/*.hpp from modules/*.ixx
├─ CMakeLists.txt            top-level: always builds core; app optional
└─ ARCHITECTURE.md           this file
```

## Core

### Sequence + concept (`se::seq`)

Searching operates on a 1-D, index-addressable range. `se::index` / `se::nil` name a
position (mirroring `sa::index` / `sa::nil`); a search returns the found index, or
`se::nil` when the target is absent. The generic-programming contract is the concept
`se::searchable<R>` — a random-access range of `std::totally_ordered` elements — and
every algorithm is `template <class T, class Compare = se::less>`, so it searches any
orderable type (numbers, strings, …). A single `se::equivalent(a, b, cmp)` helper gives
every algorithm one notion of "found" (`!cmp(a,b) && !cmp(b,a)`) without needing a
separate `operator==`.

### Instrumentation (`se::trace`)

The linchpin between core and app. A search looks like:

```cpp
template <class T, class Compare = less>
index binary_search(const std::vector<T>& a, const T& target,
                    Compare cmp = {}, const tracer& trace = ignore);
```

As it runs it emits `step{ kind, i, j, value, note, line }` values via `trace`:

| event          | meaning (visual mapping)                                      |
|----------------|---------------------------------------------------------------|
| `probe`        | examining a[i] vs the target → flash the bar                 |
| `lo_bound`     | the window's lower bound moved to i → slide the left marker  |
| `hi_bound`     | the window's upper bound moved to i → slide the right marker |
| `mid`          | i is the current midpoint / interpolation / jump probe       |
| `eliminate`    | positions [i..j] discarded → dim that region                 |
| `found`        | target located at i → settled/highlight colour               |
| `not_found`    | search exhausted; target absent                              |
| `pass_boundary`| one iteration / probe step completed → narration             |
| `message`      | free-form narration                                          |

`step` is element-agnostic (indices + a `double value` for bar heights), so one
`tracer` type serves every search.

### Algorithm catalogue

Each search is a C++20 module with a generated `.hpp` twin + trace events + tests, and
the app groups them by **category**:

- **Sequential** — `core/modules/sequential_searches/`: **Linear** (O(n), works on
  unsorted data) and **Sentinel** (the same, with the per-step bounds check removed by a
  guard element).
- **Sorted** — `core/modules/sorted_searches/` (all require the array sorted by the
  comparator): **Binary** (O(log n)), **Ternary** (two probes / three-way split, O(log
  n) but more comparisons than binary), **Jump** (block steps of ~√n, O(√n)),
  **Exponential** (galloping / doubling then binary, O(log i)), **Interpolation**
  (position guessed by linear interpolation, O(log log n) on uniform data, O(n) worst),
  and **Fibonacci** (golden-ratio bisection using only add/subtract, O(log n)).

Later phases can add more (binary-search-tree lookup, hashing, Boyer–Moore / KMP string
search, …).

### Benchmark foundation (`se::gen`, `se::bench`)

- **`se::gen`** — seeded, reproducible generators: `sorted`, `random_sorted`,
  `few_unique_sorted`, `gaussian_sorted`, `unsorted_random`, plus `present_target`
  (an element at a chosen position, for best/worst-case studies) and `missing_target`
  (an absent value that forces full depth). The input *distribution* is what separates
  binary from interpolation search, so each shape is its own generator.
- **`se::bench`** — a timing harness (`time_it` → min/median/mean/stddev,
  `do_not_optimize`) and a counting `tracer` (`count_into`) tallying probes / window
  updates — the headline cost of a search is how many elements it examined.

### The module / header twin

The `.ixx` under `core/modules/` is the single source of truth (built by the MSVC
solution with `/std:c++20` + modules). `scripts/gen_se_hpp.py` mechanically mirrors each
into `core/include/se/**.hpp` so the Qt/MinGW app and the CTest checks use the exact same
code without needing module support. The CMake build runs the script's `--check` mode and
fails if any header is stale.

## App — Search Algorithm Studio

A Qt 6 / QML desktop app: a splash → Home landing page routes to one of three workspaces
(a `page` property in `Main.qml` swaps the body; the frameless `TitleBar` is mode-aware).
Generic UI tokens + controls come from the shared **UiKit** (`../UI_repo`); search-specific
colours (the bar playback states) live in the app's `Theme` singleton.

- **Visualizer** (`VisualizerController` + `VisualizerPage.qml`) — generate a sorted array
  and a target, pick a search, and watch it run. The controller runs the core algorithm
  with a recording tracer into a step timeline, then plays it forward/back/seek, mapping
  each step to per-bar visual state (probe / in-window / eliminated / found) and a sliding
  lo/hi window. Because the array never changes (a search only reads), playback is pure
  re-colouring, so stepping backward is trivial. A synced `Pseudocode` panel highlights the
  current line.
- **Analyzer** (`AnalyzerController` + `AnalyzerPage.qml`) — a **headless** benchmark
  workspace. It sweeps the chosen searches over a list of sizes for one input distribution
  and target mode on a worker thread (progress + cancel), counting **probes** with a
  `se::bench` tracer (deterministic) and timing a batch of searches **without** a tracer
  for **ns/search**. Results stream into a table and a metric-vs-N scaling chart (with an
  O(log n) / O(√n) / O(n) overlay), and export to CSV.
- **Knowledge** (`KnowledgePage.qml` + `KnowledgeContent.qml`) — a curated, searchable
  reference: one article per search (concept, pre-condition, best/avg/worst complexity, the
  real `.ixx` path) with deep-link buttons into the Visualizer / Analyzer.

The sort studio's sort-only extras (Race, Stability, the live system monitor and per-step
sound) are intentionally omitted — they don't map onto a single-target search.

## Build

- **Core**: header-only `INTERFACE` target `se::core`; `BUILD_TESTING` adds the CTest
  checks. `cmake -S . -B build && cmake --build build && ctest --test-dir build`.
- **App**: opt in with `-DSEARCH_ALGO_BUILD_APP=ON` (needs Qt 6 + the sibling UiKit).
- **Modules (MSVC)**: open `core/search_algo.slnx` in Visual Studio 2026 to build the
  `.ixx` modules directly; after editing a `.ixx`, run `py -I scripts/gen_se_hpp.py` to
  refresh the header twins.
