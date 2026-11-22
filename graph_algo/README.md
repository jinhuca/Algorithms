# graph_algo

A learning and research hub for **graph algorithms and data structures** — a
generic, header-only **C++ core** and a Qt/QML **visualizer** that animates the
algorithms step by step. Inspired by `fsm_cpp` / `fsm_visualizer` and by
*Graphisual*.

```
core/         generic graph algorithms & data structures (modern C++20, no Qt)
studio/   Qt 6 / QML app that animates the algorithms (reuses fsm_visualizer)
```

See **[ARCHITECTURE.md](ARCHITECTURE.md)** for the design.

## Quick start (core)

```bash
cmake -S . -B build
cmake --build build
ctest --test-dir build --output-on-failure
```

Use it:

```cpp
#include <ga/graph/graph.hpp>
#include <ga/short_paths/dijkstra.hpp>

ga::graph<int> g(4);              // 4 vertices, undirected
g.add_edge(0, 1, 1);
g.add_edge(1, 2, 1);
g.add_edge(0, 3, 4);
g.add_edge(2, 3, 2);

std::vector<ga::vertex> parent;
auto dist = ga::dijkstra(g, 0, &parent);   // dist[v] = shortest distance from 0
```

Pass a `tracer` to observe (and later animate) a run:

```cpp
ga::dijkstra(g, 0, &parent, [](const ga::step& s) {
    if (s.kind == ga::evt::relax_edge)
        printf("relax %zu->%zu = %g\n", s.u, s.v, s.value);
});
```

## Status

- **Core**: `graph`, `trace`, and **BFS**, **DFS**, **Dijkstra**, **Bellman–Ford** with tests.
- **Visualizer**: working MVP — build `-DGRAPH_ALGO_BUILD_VISUALIZER=ON` (needs
  Qt 6). Run BFS/DFS/Dijkstra/Bellman–Ford on a sample graph and scrub the step-by-step playback
  (frontier/current/settled colouring, result tree, distances). See
  [studio/README.md](studio/README.md).

Roadmap in [ARCHITECTURE.md](ARCHITECTURE.md).
