# Graph Algorithm Studio

A Qt 6 / QML desktop app with two workspaces on top of the `ga::core` library,
reached from a Home landing page (splash → Home → workspace, with a Home button to
return):

- **Visualizer** — **build a graph, choose an algorithm, and watch it run** step by
  step (the *Graphisual* experience).
- **Analyzer** — **headless benchmarks**: no rendering, so you can push very large
  graphs through the algorithms and measure time, operations and peak memory.

Not built by default; enable with `-DGRAPH_ALGO_BUILD_VISUALIZER=ON` (requires Qt 6).
(The target/exe keep the name `graph_visualizer` so existing user settings survive.)

## Reused from `fsm_visualizer`

- **`GraphView`** canvas — draggable circular nodes, curved/self edges with
  arrowheads and labels, zoom/pan, de-overlapped labels, fit-to-content, and
  PNG/SVG export.
- **`Theme`** singleton (light/dark, drives the Controls palette), frameless
  **`TitleBar`**, and the **`Dialogs`** component.
- The **controller bridge** pattern (a `QObject` exposing the model to QML) and
  the **save/load/session** + document-JSON machinery.

## New for this app

- **Interactive graph building**: add/remove vertices and edges on the canvas,
  edit edge **weights**, toggle **directed/undirected**.
- **Algorithm panel**: pick the algorithm + source (+ target for A*).
- **Step-timeline playback**: the controller runs a `ga::core` algorithm with a
  `tracer` that records each `ga::step`; the UI plays that timeline with
  play / pause / **step** / **step-back** / speed, mapping each step to node/edge
  highlights (frontier, current, settled, tree edge, relaxed, path).
- **Overlays**: per-vertex distance/discovery labels; highlighted result tree or
  shortest path.

## Bridge sketch (`VisualizerController`)

```
QML (GraphView + build/algorithm/playback panels)
      │
      ▼
VisualizerController (QObject)  ── builds ga::graph<double>, runs the chosen algo with
      │                       a recording tracer, exposes the step timeline +
      ▼                       a cursor and the current per-vertex/edge state
ga::core (pure C++)  ── emits ga::step ──▶ recorded timeline ──▶ QML animates
```

See [../ARCHITECTURE.md](../ARCHITECTURE.md) for the full design and roadmap.

## Build & run

```powershell
cmake -S .. -B ../build -G Ninja -DGRAPH_ALGO_BUILD_VISUALIZER=ON `
  -DCMAKE_CXX_COMPILER=C:/Qt/Tools/mingw1310_64/bin/g++.exe `
  -DCMAKE_RC_COMPILER=C:/Qt/Tools/mingw1310_64/bin/windres.exe `
  -DCMAKE_MAKE_PROGRAM=C:/Qt/Tools/Ninja/ninja.exe `
  -DCMAKE_PREFIX_PATH=C:/Qt/6.12.0/mingw_64
cmake --build ../build
```

Run `build/studio/graph_visualizer.exe` (with the Qt `bin` on `PATH`, or
deploy with `windeployqt` as in `fsm_studio/packaging`).

## Status — MVP working

- Frameless window, `Theme` (light/dark), `TitleBar`, and the `GraphView` canvas
  (zoom/pan, draggable nodes, weighted edges, directed arrowheads).
- `VisualizerController` builds a sample weighted graph, runs **BFS**, **DFS**, **Dijkstra**, **Bellman–Ford**
  from a chosen source, and records the `ga::step` stream into a per-step
  timeline.
- Playback: Run, step forward/back, play/pause, speed, and a scrub slider, with
  live colouring — frontier / current / settled vertices, the result tree, the
  current step's edge, Dijkstra distance chips, and a one-line narration.
- **Highlight a path**: after a run, pick a target in the **Path to** combo (or
  click a node on the canvas) to light up the source→target path through the
  result tree — the edges draw bold in a distinct colour, the target pulses, and
  the panel shows the hop count (plus the shortest-path **cost** for Dijkstra /
  Bellman–Ford). Click the target again, or **✕**, to clear it.
- **Interactive graph building**: double-click the canvas to add a node,
  double-click a node to rename it, drag it to move (only that vertex moves; its
  edges follow), right-click to delete it (and its edges);
  toggle **Add edge** then tap a source and target node to connect them with the
  chosen **weight** (click an edge's weight chip to edit it, right-click it to
  delete the edge); **Sample** reloads the demo graph, the **Layout** menu
  auto-arranges the vertices (force-directed or circular), **Clear** empties the
  canvas, **Directed** flips direction. Edges that would overlap (reciprocal
  directed pairs) or cross a vertex bow into curves automatically; **Undo/Redo**
  (Ctrl+Z / Ctrl+Y) covers every edit.
- **Canvas navigation**: zoom to the cursor with Ctrl+wheel, or use the on-canvas
  zoom −/＋ / **Fit** controls (click the zoom % to reset to 100%). Drag the
  separator between the control panel and the canvas to resize them, or hit
  **⛶ Full screen** (Esc to exit) to hide the panel and run from a compact
  on-canvas bar.
- **Load test data fast**: a **Sample** library (Weighted demo, Grid 4×4, Binary
  tree, Complete K5, Negative cycle), **Paste edges…** to build a graph from a
  text edge list (`from to [weight]` per line; `#` comments; Replace or Append),
  and **Save…/Load…** the whole graph (vertices, edges, weights, positions,
  directedness) as JSON.

## Analyzer workspace

A headless benchmark workspace (`AnalyzerController` + `AnalyzerPage.qml`) reached
from the Home page. Pick algorithms, a graph **family** (random / grid / scale-free /
complete), a list of **sizes** N, and options (directed, weighted, avg degree, reps,
seed); **Run** sweeps every (algorithm × size) cell on a worker thread (with
**progress** and **Cancel**), timing each run with no tracer (pure computation).

- **Results table** — min / median / mean / σ (ms), operation count, and **peak
  memory**, with each algorithm's **Big-O** complexity beside it.
- **Scaling chart** — mean time *or* peak memory vs N, one line per algorithm.
- **Export CSV**, and the config is remembered across sessions.

Built on `ga::gen` (seeded graph generators) and `ga::bench` (timing harness, op
counters, peak-heap tracking) in the core. See [../AddAnalyser.md](../AddAnalyser.md).

### Next

- Save/load + document JSON, PNG/SVG/DOT export, more algorithms, and a per-user
  installer (reusing the `fsm_visualizer` packaging).
- Analyzer: a "use loaded file" benchmark source and per-job guardrails.
