# ga::core

Header-only, generic graph algorithms and data structures (C++20, no
dependencies). Namespace `ga` ("graph algorithms").

## Layout

```
include/ga/
  graph.hpp              ga::graph<W>  — index-based, directed/undirected, weighted
  trace.hpp              ga::step / ga::tracer — the step-emitting instrumentation
  algorithms/
    bfs.hpp              breadth-first search (parent tree)
    dfs.hpp              depth-first search (parent tree)
    dijkstra.hpp         non-negative single-source shortest paths
    bellman_ford.hpp     shortest paths with negative weights + cycle detection
  ds/                    (planned) disjoint-set, indexed priority queue, …
tests/
  test_core.cpp          dependency-free checks (CTest)
```

## Model in one minute

- Vertices are `std::size_t` in `0..order()-1`. No labels/positions here — those
  belong to the visualizer, keyed by vertex id.
- `ga::graph<W>` stores an adjacency list of `ga::edge<W>{from,to,weight}`.
  `W` defaults to `double`; unweighted graphs use weight `1`.
- Every algorithm is a free function taking `const graph<W>&`, returning its
  result, with a trailing `const tracer& = ignore`. It emits `ga::step`s
  (discover / visit / finish vertex, examine / tree / relax / skip edge) so the
  same run can be printed, tested, or animated.

## Adding an algorithm

The C++20 module sources under `modules/` are the source of truth; the headers
under `include/ga/` are GENERATED from them by `scripts/gen_ga_hpp.py` so the
Qt/MinGW visualizer and these tests (which can't use modules) stay in sync.

1. Author the module in the matching family folder, e.g.
   `modules/short_paths/<name>.ixx` — `export module ga.short_paths.<name>;`
   then `import ga.graph; import ga.trace;`, a templated free function in
   `export namespace ga`, emitting trace steps at the meaningful moments. Add it
   to that family's `.vcxproj` (and `.filters`) in `graph_algo.slnx`.
2. Run `py -I scripts/gen_ga_hpp.py` — it writes the twin
   `include/ga/short_paths/<name>.hpp`. (CMake fails the build if a header is
   stale; `--check` verifies.)
3. Add checks to `tests/test_core.cpp` (header-based, MinGW/CMake) and/or
   `modules/tests/test_modules.cpp` (import-based, MSVC), keeping them
   framework-free.
4. List it in [../ARCHITECTURE.md](../ARCHITECTURE.md) and the catalogue above.

## Build / test

```bash
cmake -S .. -B ../build && cmake --build ../build
ctest --test-dir ../build --output-on-failure
```

Or consume from another CMake project: `add_subdirectory(core)` then link
`ga::core`.
