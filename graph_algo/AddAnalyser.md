# Add a Graph Algorithm **Analyzer** module

## Original intent

Add a second Qt module — a **Graph Algorithm Analyzer** — alongside the existing
visualizer. New workflow:

```
splash  ->  Home page  ->  [ Graph Algorithm Analyzer ]   [ Graph Algorithm Visualizer ]
                                        |                               |
                                 headless benchmarks            interactive canvas
                                        |                               |
                                 (both have a "Home" control to return to the landing)
```

The **Analyzer** runs algorithmic benchmarks with **no graphics rendering**, so the
user can push very large data sets through the algorithms and measure performance.
We also rebrand the app from "Graph Algorithm Visualizer" to an umbrella name that
hosts both modules.

---

## Target architecture

Reuse everything that is already generic; add one new bridge + one new QML page.

```
                 ApplicationWindow (frameless, Theme, splash)   ← reused shell
                              │
                       AppShell router (StackView / Loader)      ← NEW
             ┌────────────────┼─────────────────────┐
         HomePage        VisualizerPage          AnalyzerPage     ← NEW pages
          (NEW)        (today's Main body)           (NEW)
                              │                         │
                       VisualizerController           AnalyzerController  ← NEW QObject
                              │                         │
                              └──────── ga::core ───────┘           ← reused, extended
                                        (tracer = ignore ⇒ pure, fast compute)
```

Key reuse points, verified in the current code:

- **One window, routed.** Keep the single frameless `ApplicationWindow`, `Theme`,
  `TitleBar`, splash, and QSettings machinery. Introduce a router so the body swaps
  between Home / Visualizer / Analyzer instead of always showing the graph canvas.
- **`tracer = ignore` ⇒ benchmark mode.** Core algorithms already take
  `const tracer& = ignore` last (ARCHITECTURE principle #2). The analyzer calls them
  **without** a tracer → no step recording, no snapshots, no rendering: just the raw
  computation we want to time. `VisualizerController_run.cpp` shows the paired "build
  `ga::graph<double>` + `QElapsedTimer`" pattern to mirror.
- **Core stays pure.** Benchmark workloads (random/grid/scale-free graph
  generators) go in `core/` as a new `ga::gen` facility so they are testable and Qt-free.

---

## Decisions to confirm (defaults chosen so work can start)

1. **Umbrella name** — recommend **"Graph Algorithm Studio"** (alt: "Lab",
   "Workbench", "Hub"). Used in splash, window title, Home page heading, About.
2. **QSettings identity** — **keep** `applicationName = "graph_visualizer"` so existing
   users' saved window geometry / theme / accent survive. Only display strings change.
   (If we must rename the key, add a one-time migration that copies old keys.)
3. **Landing behaviour** — always open on Home (simplest), OR remember the last-used
   module in QSettings and reopen there with Home one click away. Recommend: **always
   Home** first, revisit later.
4. **Analyzer result view** — start with a **results table + CSV export**; add an
   in-app scaling chart (time vs N) as a fast follow. (If a chart is in scope from
   day one, the `dataviz` skill governs its colours/layout.)

---

## Phase 1 — App shell, Home page, rebrand  ✅ DONE

Goal: the window boots to a Home page with two entry cards; each module can return
Home. No analyzer logic yet (Analyzer card opens a stub page).

> **Implementation note / deviation:** the router is an **in-place visibility swap**
> (`win.page` toggles `visible` on each page), *not* a `StackView` with the body
> extracted into `VisualizerPage.qml`. Reason: the window-level functions (undo
> history, session restore, 3D prep-gate, autosave) reference the child ids
> `graph` / `graph3d` / `ctl` / `player` / `dialogs` / `runBar`, and QML ids can't
> cross a component boundary — extracting would mean rewiring dozens of references
> on a subtle, working file. The visibility swap gives the identical UX at near-zero
> risk. Verified: builds clean, Home renders (light+dark), clicking a card routes to
> the Visualizer with the Home button + pickers correct.

- [x] **Router.** `win.page` ("home" | "visualizer" | "analyzer") gates `visible` on
  the `SplitView` (visualizer) and the two new pages, all siblings in `Main.qml`.
  Nav helpers: `goHome()` / `showVisualizer()` / `showAnalyzer()`.
- [x] **HomePage.qml** — centered landing: logo, "Graph Algorithm Studio" title, two
  hover-lift cards ("Analyzer" / "Visualizer") each emitting a navigate signal.
- [x] **AnalyzerPage.qml** — stub ("coming in a later phase"); real content in Phase 4.
- [x] **TitleBar mode-awareness.** New `page` property + `homeRequested` signal; a
  **"⌂ Home"** button + module label show off the home page, and the
  Category/Algorithm/Data-Set pickers are wrapped in a `RowLayout` visible only on the
  visualizer page. Theme/accent + window buttons stay on every page.
- [x] **Rebrand strings** — splash text in [main.cpp](studio/main.cpp#L45),
  window `title` and TitleBar `title` → "Graph Algorithm Studio". `setApplicationName`
  left as `graph_visualizer` (decision #2). README/ARCHITECTURE headings: TODO (Phase 5).
- [x] **State hygiene on navigation** — `goHome()` / `showAnalyzer()` call
  `stopPlay()` and clear `graph.edgeMode` so playback doesn't tick off the canvas.

## Phase 2 — Core benchmark foundation (`ga::core`, Qt-free)  ✅ DONE

Goal: generate large graphs and measure algorithm cost deterministically, with tests.

- [x] **Graph generators** — `core/modules/gen/gen.ixx` → `core/include/ga/gen/gen.hpp`
  (module `ga.gen`, namespace `ga::gen`), all seeded + reproducible:
  - `random_gnm(n, m, directed, seed, wmin, wmax)` — Erdős–Rényi, exact m distinct edges.
  - `grid(rows, cols, …)` — 4-neighbour lattice, predictable diameter.
  - `scale_free(n, m, seed, …)` — Barabási–Albert preferential attachment (hubs).
  - `complete(n, directed, …)` — dense Θ(n²) stress case.
  - Weighted via `wmin==wmax` (constant) or a `[wmin,wmax]` uniform range.
- [x] **Timing harness** — `core/modules/bench/bench.ixx` → `ga/bench/bench.hpp`
  (module `ga.bench`, namespace `ga::bench`): `time_it(fn, runs, warmup)` →
  `{runs, min, median, mean, stddev}` ms via `std::chrono::steady_clock`, plus
  `do_not_optimize()` so unused results aren't elided.
- [x] **Op-counters** — `bench::counters` + `bench::count_into(c)` returns a counting
  `tracer` for a SEPARATE untimed run (documented not to mix into timed runs).
- [x] **Tests** — `core/tests/test_gen_bench.cpp` (registered in CTest): exact
  order/size for each generator, clamping, **same-seed determinism** (and different
  seed differs), weight-range respected, generated graphs run through BFS/Dijkstra,
  and the harness/counters report sane values. `ctest` → 2/2 pass; header sync check green.

> **Remaining (MSVC-only, not verifiable in this MinGW env):** register the two new
> `.ixx` in the Visual Studio solution so `graph_algo.slnx` compiles the modules too
> — add `core/modules/gen/gen.vcxproj` + `core/modules/bench/bench.vcxproj` (mirroring
> `basic_algo.vcxproj`) and reference them from the `.slnx`. The consumed `.hpp`
> twins are already generated and tested, so the studio/analyzer build is
> unaffected; this only keeps the `.ixx` source-of-truth building on MSVC.

## Phase 3 — AnalyzerController bridge (`QObject`)  ✅ DONE (runtime check in Phase 4)

Goal: drive benchmarks off the GUI thread and publish results to QML.

- [x] **`AnalyzerController.h/.cpp`** sibling to `VisualizerController`, `QML_ELEMENT`-
  registered (added to `qt_add_executable` in
  [studio/CMakeLists.txt](studio/CMakeLists.txt)).
- [x] **Job model** — `Q_INVOKABLE run(QVariantMap config)` with keys
  { algorithms[], family, sizes[], directed, weighted, avgDegree, reps, warmup, seed,
  countOps }. Builds each `ga::graph<double>` once via `ga::gen`, runs each algorithm
  **without a tracer** (pure compute) timed by `ga::bench::time_it`.
- [x] **Threading** — detached `std::thread` + `QMetaObject::invokeMethod(…, QueuedConnection)`
  to marshal back (mirrors `loadFromFileAsync`). `running` / `progress` (0..1) /
  `status` properties; results **stream in per cell**; `cancel()` sets an atomic flag
  checked between cells.
- [x] **Results exposure** — `results` `QVariantList` of rows
  { algorithm, family, n, m, reps, minMs, medianMs, meanMs, stddevMs, ops } + a
  separate untimed counted run for `ops`; `Q_INVOKABLE exportCsv(url)`.
- [ ] **Reuse the file loader** — benchmark a **loaded** graph (shared JSON→graph
  parse refactored out of `VisualizerController_io.cpp`). **Deferred** — not needed for the
  synthetic-graph sweeps; revisit alongside the Phase 4 "use loaded file" option.

> Compiles, links, and registers as a QML type; the threading/marshaling pattern is
> identical to the proven `loadFromFileAsync`, and the benchmark core it drives is
> unit-tested (Phase 2). End-to-end runtime verification happens in Phase 4 when the
> `AnalyzerPage` UI drives it (visible results + screenshots).

## Phase 4 — Analyzer QML UI  ✅ DONE (core UI; chart + guardrails are fast-follow)

Goal: configure, run, and read benchmarks — no canvas, no per-step rendering.

- [x] **AnalyzerPage.qml** layout: left = **config panel** (algorithm multi-select
  checkboxes, graph-family combo, comma-separated sizes field, directed + weighted
  toggles, avg-degree / reps / seed spin boxes); right = **results table**.
- [x] Table bound to `AnalyzerController.results`; **Run / Cancel** (Cancel enabled
  only while running), a **ProgressBar** on `progress`, a **status** line, **Clear**,
  and **Export CSV** via a `FileDialog`. Results stream in row-by-row.
- [x] **Verified end-to-end** — drove the real app: Home → Analyzer card → Run on the
  default sweep (BFS + Dijkstra × N = 1000/5000/20000, weighted random). Got sensible
  scaling (time ~linear in N, Dijkstra ≈ 2× BFS, `ops` ∝ size), progress → Done, table
  filled live. See `Screenshots/phase4_analyzer.png` + `phase4_results.png`.
- [x] **Peak memory profiling** (added on request) — a `peak mem` column + `peak_bytes`
  in the CSV. `ga::bench::mem` holds thread-local peak-heap counters; a global
  new/delete override ([studio/mem_tracker.cpp](studio/mem_tracker.cpp), using
  `_msize`, non-aligned operators only) feeds them, gated on a thread-local `tracking`
  flag so it costs ~nothing except during one dedicated untimed measuring run per cell
  (kept separate from the timed + counted runs). Measured values match the algorithms'
  data-structure footprints (BFS ≈ O(V); Dijkstra ≈ 2.7× — three V-arrays + an O(E)
  heap), scaling ~linearly with N.
- [x] **Scaling chart** — [ScalingChart.qml](studio/qml/ScalingChart.qml): line
  chart of a metric vs N, one series per algorithm, with a **Time / Memory** metric
  toggle (single y-axis — never dual-axis, per the dataviz rules). Colours are the
  dataviz categorical palette assigned by the algorithm's fixed index (stable hue per
  algorithm, light/dark variants), with gridlines, axis labels, x-ticks at the real
  sizes, and a legend. Verified for both metrics — see `Screenshots/phase4_results.png`
  (time) and `phase4_memchart.png` (memory).
- [x] **Big-O column** — the results table shows each algorithm's worst-case time
  complexity (binary-heap Dijkstra/Prim) beside its measured numbers.
- [ ] **(Fast follow)** guardrails — warn before obviously huge jobs (e.g. complete
  graph at large N) and the slow O(V·E) Bellman-Ford; surface errors without crashing.
- [ ] **(Fast follow)** "use loaded file" option (ties to the deferred Phase 3 shared
  loader) — benchmark a JSON graph instead of a synthetic one.

## Phase 5 — Polish, tests, docs, packaging  ✅ DONE

- [x] Persist analyzer config in QSettings — a `Settings { category: "analyzer" }`
  block in [AnalyzerPage.qml](studio/qml/AnalyzerPage.qml) (own group, no clash
  with the visualizer's keys): selected algorithms, family, sizes, directed/weighted,
  avg degree, reps, seed, and the chart metric. Round-trip verified by pre-seeding the
  registry and confirming the page restored the values.
- [x] Updated [ARCHITECTURE.md](ARCHITECTURE.md): `ga::gen` / `ga::bench` in the
  layout, a "Benchmark foundation" subsection, a "Studio shell + the Analyzer"
  subsection, and roadmap item 5.
- [x] Updated [studio/README.md](studio/README.md): Studio intro (two
  workspaces) + an Analyzer section. (Directory kept as `studio/`; the exe stays
  `graph_visualizer` so saved settings survive.)
- [x] Packaging: the new QML files are in the `GraphVis` module's `QML_FILES`, so they
  compile into the exe and ship via the existing `windeployqt` flow unchanged.
- [x] Run auto-clears previous results (so a fresh sweep = one clean set of series).
- [~] Smoke: Home ↔ Visualizer and Home ↔ Analyzer, a benchmark sweep, CSV path, and
  config persistence all exercised in the running app across phases 1/4/5. (A full
  scripted splash-to-exit pass wasn't automated — synthesized clicks are flaky here.)

### Deferred (cross-cutting, tracked)

- [ ] Register the new `.ixx` in the MSVC solution (`graph_algo.slnx`) — MSVC-only,
  couldn't verify in this MinGW env; the consumed `.hpp` twins are generated + tested.
- [ ] Shared JSON→graph loader + a "use loaded file" Analyzer source.
- [ ] Per-job guardrails (warn on huge complete graphs / slow Bellman-Ford).

---

## Files to touch (first pass)

| File | Change |
|------|--------|
| `studio/qml/Main.qml` | Host `StackView`; move body to `VisualizerPage.qml` |
| `studio/qml/HomePage.qml` | **new** landing with two entry cards |
| `studio/qml/VisualizerPage.qml` | **new** — today's SplitView + RunBar body |
| `studio/qml/AnalyzerPage.qml` | **new** — config + results table |
| `studio/qml/TitleBar.qml` | mode-aware middle region + "⌂ Home" button |
| `studio/main.cpp` | splash text rebrand (keep `applicationName`) |
| `studio/AnalyzerController.{h,cpp}` | **new** QObject bridge + results model |
| `studio/VisualizerController_io.cpp` | extract shared JSON→graph loader |
| `studio/CMakeLists.txt` | register new sources + QML files + QML type |
| `core/include/ga/gen/*`, `core/modules/gen/*.ixx` | **new** graph generators |
| `core/include/ga/bench/*` | **new** timing harness |
| `core/tests/` | generator + harness tests |
| `ARCHITECTURE.md`, `studio/README.md` | docs |

## Risks / notes

- **Settings path.** Renaming `setApplicationName` silently abandons users' saved
  window geometry/theme/accent — keep it, change only display strings (decision #2).
- **Don't benchmark with a tracer.** Recording steps is the visualizer's job; it would
  dominate the timings. Timed runs must pass `ga::ignore` (the default).
- **UI thread.** Large sweeps must run on a worker with cancel; a synchronous
  1e6-edge run would hang the frameless window (no OS chrome to signal "busy").
- **Determinism.** All generators seeded so results are comparable across runs/machines.
- **Generated headers.** Core `.hpp` are generated from `.ixx` and a build check fails
  on drift — add new core code as a module `.ixx` and regen with `scripts/gen_ga_hpp.py`.
