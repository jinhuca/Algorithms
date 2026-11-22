# graph_algo — architecture

A learning and research hub for **graph algorithms and data structures**: a
clean, generic C++ **core** library, plus a Qt/QML **visualizer** that animates
the algorithms step by step. Inspired by `fsm_cpp` (a header-only generic
`fsm::dfa`) and `fsm_visualizer` (its Qt/QML front-end), and by web tools like
*Graphisual — Free Graph & Algorithm Visualizer*.

## Guiding principles

1. **Core is pure, visualizer is presentation.** The core computes; it knows
   nothing about Qt, colours, positions or labels. The visualizer owns all of
   that. Either can evolve independently, and the core is usable on its own (in
   tests, CLIs, research code).
2. **One instrumentation hook, two uses.** Every algorithm takes an optional
   `tracer` callback and emits a stream of `step`s. With no tracer it's a plain,
   fast computation; with one, a UI or a test observes the exact same run and
   animates it. (This is the `fsm::dfa::subscribe` idea applied to algorithms.)
3. **Generic and modern.** Templated on the edge-weight type, index-based
   vertices for cache-friendly algorithms, C++20 (concepts/ranges) today with
   room to adopt modules later, mirroring `fsm.ixx`.
4. **Readable first.** This is a teaching hub: implementations favour clarity,
   each is documented, and the trace events double as a narration of how the
   algorithm works.

## Repository layout

```
graph_algo/
├─ core/                     header-only C++ library (no Qt)
│  ├─ include/ga/
│  │  ├─ graph.hpp           ga::graph<W> — generic index-based graph
│  │  ├─ trace.hpp           ga::step / ga::tracer — the instrumentation hook
│  │  ├─ algorithms/         one header per algorithm (bfs.hpp, dijkstra.hpp, …)
│  │  ├─ gen/                synthetic graph generators (ga::gen) for benchmarks
│  │  └─ bench/              timing harness + peak-heap counters (ga::bench)
│  ├─ tests/                 dependency-free checks (CTest)
│  └─ CMakeLists.txt         INTERFACE target  ga::core
├─ studio/               Qt 6 / QML app — "Graph Algorithm Studio" (opt-in build)
│  └─ README.md              design + what it reuses from fsm_visualizer
├─ CMakeLists.txt            top-level: always builds core; visualizer optional
└─ ARCHITECTURE.md           this file
```

## Core

### Graph model (`ga::graph<W>`)

- **Vertices are integers `0..order()-1`** — ideal as array indices, which is
  what graph algorithms want. Labels, positions and colours are *not* here; they
  live in the visualizer, keyed by vertex id.
- **Edges carry a weight of type `W`** (default `double`); unweighted graphs use
  weight `1`. Directed or undirected (an undirected edge is stored as the two
  opposing directed edges, so adjacency queries stay uniform).
- Adjacency-list storage (`vector<vector<edge<W>>>`) — the right default for the
  sparse graphs these algorithms target.

Planned additions: an adjacency-matrix view for dense/all-pairs work, and
companion data structures used by the algorithms — **disjoint-set / union-find**
(MST, connectivity), indexed priority queue, etc. — under `include/ga/ds/`.

### Instrumentation (`ga::trace`)

The linchpin between core and visualizer. An algorithm signature looks like:

```cpp
template <class W>
std::vector<vertex> bfs(const graph<W>& g, vertex src,
                        const tracer& trace = ignore);
```

As it runs it emits `step{ kind, u, v, value, note }` values via `trace`:

| event             | meaning (visual mapping)                              |
|-------------------|-------------------------------------------------------|
| `discover_vertex` | first reached / enqueued → **frontier** colour        |
| `visit_vertex`    | taken off the frontier → **current** highlight        |
| `finish_vertex`   | done → **settled** colour                             |
| `examine_edge`    | edge under consideration → flash the edge             |
| `tree_edge`       | edge kept in the result tree → bold/accent the edge   |
| `relax_edge`      | shorter path found (`value` = new distance) → update label |
| `skip_edge`       | edge rejected → dim                                   |
| `found_target`    | goal reached → pulse                                  |
| `message`         | free-form narration                                   |

`step` is deliberately weight-agnostic (plain vertex ids + a `double value`), so
a single `tracer` type serves every algorithm.

### Algorithm catalogue (planned)

Implemented: **BFS**, **DFS** (`basic_algo`), **Dijkstra**, **Bellman–Ford**
(`short_paths`) — all source-based, each a C++20 module under
`core/modules/<family>/<name>.ixx` with a generated `core/include/ga/<family>/<name>.hpp`
twin + a test + trace events. Planned:

- Traversal: DFS timestamps, iterative-deepening.
- Shortest paths: A*, Floyd–Warshall (all-pairs).
- Spanning trees: Kruskal, Prim.
- Ordering / structure: topological sort, connected components, strongly
  connected components (Tarjan / Kosaraju), cycle detection, bipartite check.
- Flows (later): Edmonds–Karp / Dinic.

Convention: algorithms are free functions in `namespace ga`, take the graph by
`const&`, return their result, and take `const tracer& = ignore` last.

### Benchmark foundation (`ga::gen`, `ga::bench`)

Qt-free facilities that back the Analyzer (below):

- **`ga::gen`** (`include/ga/gen/gen.hpp`) — seeded, reproducible synthetic graph
  generators: `random_gnm` (Erdős–Rényi), `grid`, `scale_free` (Barabási–Albert) and
  `complete`, each with an optional `[wmin, wmax]` weight range.
- **`ga::bench`** (`include/ga/bench/bench.hpp`) — a timing harness (`time_it` →
  min/median/mean/stddev, plus `do_not_optimize`), a counting `tracer` (`count_into`)
  for operation totals, and thread-local peak-heap counters (`mem::*`) that an
  executable activates by linking a global `new`/`delete` override.

Both follow the module convention: the `.ixx` under `core/modules/` is the source of
truth, its generated `.hpp` twin is what the app and tests consume.

## Visualizer

A Qt 6 / QML desktop app that lets you **build a graph, pick an algorithm, and
watch it run** with play / pause / step / step-back / speed controls — the
Graphisual experience, on top of the real C++ core.

### Reused from `fsm_visualizer`

- The **QML graph canvas** (`GraphView`): nodes as draggable circles, curved/
  self edges with arrowheads and labels, zoom/pan, de-overlapped labels, the
  fit-to-content view, and **PNG/SVG export**.
- The **`Theme` singleton** (light/dark palette driving the Controls palette),
  the frameless **`TitleBar`**, and the **`Dialogs`** component.
- The **controller bridge pattern**: a `QObject` (there `FsmVisController`)
  exposing the model to QML via properties/signals and `Q_INVOKABLE`s, and the
  session autosave / save-load-as / document JSON machinery.

### New for graph algorithms

- **Interactive graph building**: add/remove vertices and edges on the canvas,
  set edge **weights**, toggle **directed/undirected** — not just a text form.
- **Algorithm panel**: choose the algorithm and the source (and target, for A*).
- **Playback of a step timeline**: the controller runs a core algorithm with a
  `tracer` that records every `step` into a list; the UI then plays that list —
  forward, backward, single-step, with a speed slider — mapping each `step` to
  the visual states in the table above. Running = replaying a precomputed trace,
  so stepping backward is trivial.
- **State overlays**: per-vertex distance / discovery labels, frontier vs.
  settled colours, highlighted result tree / shortest path.

### The bridge (`VisualizerController`)

```
QML (GraphView + panels)
        │  build graph, pick algo, play/step/speed
        ▼
VisualizerController  (QObject)
        │  holds ga::graph<double>; on "run" calls e.g. ga::dijkstra(g, src, …,
        │  tracer=[&](step s){ steps_.push_back(s); })
        ▼
ga::core  (pure C++)  ── emits steps ──▶ recorded timeline ──▶ QML animates
```

The controller converts between QML's vertex ids and `ga::vertex`, exposes the
recorded `step` timeline and a cursor, and publishes the current per-vertex /
per-edge visual state for the canvas to bind to.

### Studio shell + the Analyzer

The app is **Graph Algorithm Studio**: a splash → Home landing page routes to one of
two workspaces. A `page` property in `Main.qml` swaps the body (Home / Visualizer /
Analyzer) and the title bar is mode-aware (a Home button + module label; the
algorithm/data-set pickers show only on the visualizer page).

- **Visualizer** — the interactive canvas described above.
- **Analyzer** (`AnalyzerController` + `AnalyzerPage.qml`) — a **headless** benchmark
  workspace (no rendering, so very large graphs are fine). It sweeps the chosen
  algorithms over a list of sizes on a worker thread (progress + cancel), timing each
  run **without a tracer** (pure computation) via `ga::bench`, plus a separate untimed
  counted run for operation totals and another for peak memory. Results stream into a
  table (with each algorithm's Big-O complexity and peak memory) and a time/memory-vs-N
  scaling chart, and export to CSV; the config persists in its own QSettings group.

## Build

- **Core**: header-only `INTERFACE` target `ga::core`; `BUILD_TESTING` adds the
  CTest checks. `cmake -S . -B build && cmake --build build && ctest`.
- **Visualizer**: opt in with `-DGRAPH_ALGO_BUILD_VISUALIZER=ON` (needs Qt 6).
  Packaging will follow the `fsm_visualizer` approach (windeployqt + installer).

## Roadmap

1. **Core foundation** (done): `graph`, `trace`, BFS + Dijkstra, tests, CMake.
2. **Visualizer MVP** (done): `VisualizerController` bridge + ported `GraphView`;
   runs BFS/Dijkstra on a sample graph with step-timeline playback (frontier /
   current / settled colouring, result tree, Dijkstra distances, narration).
3. **Core breadth**: DFS + Bellman–Ford (done); next topological sort,
   union-find + Kruskal/Prim, components/SCC, A*.
4. **Visualizer depth**: interactive graph building (add/remove vertices &
   edges, edge weights, directed toggle) — done; next export (PNG/SVG/DOT),
   save/load, and a per-user installer (reusing the `fsm_visualizer` packaging).
5. **Graph Algorithm Studio** (done): Home router + a headless **Analyzer** —
   benchmark sweeps on `ga::gen` / `ga::bench` (timing + op counts + peak memory),
   a scaling chart and CSV export. Next: a "use loaded file" benchmark source and
   per-job guardrails.
