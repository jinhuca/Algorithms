pragma ComponentBehavior: Bound
import QtQuick

// Curated knowledge base for the Knowledge workspace: one entry per graph
// algorithm / data structure the studio implements, plus a project-architecture
// note. Each `body` is Markdown (rendered by KnowledgePage with Text.MarkdownText)
// and follows the same shape: Idea → Complexity → Implementation in this project
// (the real .ixx source + a verbatim excerpt) → References.
//
// Bodies are built by join()-ing arrays of double-quoted lines, so Markdown
// fenced code blocks (```), which use backticks, stay literal and need no escaping
// (a QML template literal would also capture the source indentation — avoided here).
QtObject {
    // Join helper so topic bodies read as line arrays.
    function md(lines) { return lines.join("\n"); }

    readonly property var topics: [
        // ---------------- Algorithms ----------------
        {
            id: "bfs", category: "Algorithms", glyph: "🌊", title: "Breadth-First Search",
            summary: "Level-by-level traversal of an unweighted graph using a FIFO queue.",
            complexity: "O(V + E)",
            props: ["traversal", "unweighted", "queue"],
            source: "core/modules/basic_algo/bfs.ixx → core/include/ga/basic_algo/bfs.hpp",
            related: { visualize: "BFS", benchmark: "BFS" },
            references: [
                { title: "CLRS §22.2 — Breadth-first search", url: "https://en.wikipedia.org/wiki/Breadth-first_search" }
            ],
            body: md([
                "## Idea",
                "BFS explores a graph in expanding *frontiers*: it visits the source, then all its neighbours, then their unvisited neighbours, and so on. A **FIFO queue** holds the frontier, so vertices come out in the order they were discovered — which makes the BFS tree a shortest-path tree in terms of *edge count*.",
                "",
                "## Complexity",
                "- Time: **O(V + E)** — every vertex dequeued once, every edge examined once.",
                "- Space: **O(V)** for the queue, `seen[]` and `parent[]`.",
                "",
                "## Implementation in this project",
                "Source: `core/modules/basic_algo/bfs.ixx`. A `std::queue<vertex>` drives the frontier; `parent[]` records the tree (`parent[src] == src`, `nil` for unreached). Trace events let the Visualizer animate the frontier:",
                "",
                "```cpp",
                "seen[src] = 1; parent[src] = src; q.push(src);",
                "trace({evt::discover_vertex, src});",
                "while (!q.empty()) {",
                "  const vertex u = q.front(); q.pop();",
                "  trace({evt::visit_vertex, u});",
                "  for (const auto& e : g.out(u)) {",
                "    trace({evt::examine_edge, u, e.to});",
                "    if (!seen[e.to]) {",
                "      seen[e.to] = 1; parent[e.to] = u; q.push(e.to);",
                "      trace({evt::tree_edge, u, e.to});",
                "      trace({evt::discover_vertex, e.to});",
                "    } else trace({evt::skip_edge, u, e.to});",
                "  }",
                "  trace({evt::finish_vertex, u});",
                "}",
                "```",
                "",
                "See also the **Trace / step event model** and **Graph (adjacency list)** topics."
            ])
        },
        {
            id: "dfs", category: "Algorithms", glyph: "🧭", title: "Depth-First Search",
            summary: "Dive as deep as possible before backtracking — here iterative, not recursive.",
            complexity: "O(V + E)",
            props: ["traversal", "unweighted", "explicit stack"],
            source: "core/modules/basic_algo/dfs.ixx → core/include/ga/basic_algo/dfs.hpp",
            related: { visualize: "DFS", benchmark: "DFS" },
            references: [
                { title: "CLRS §22.3 — Depth-first search", url: "https://en.wikipedia.org/wiki/Depth-first_search" }
            ],
            body: md([
                "## Idea",
                "DFS follows one path as far as it can, then backtracks to the last vertex with an unexplored edge. It classifies edges (tree / back / cross / forward) and underlies topological sort, cycle detection and SCCs.",
                "",
                "## Complexity",
                "- Time: **O(V + E)**.  Space: **O(V)** for the stack and marks.",
                "",
                "## Implementation in this project",
                "Source: `core/modules/basic_algo/dfs.ixx`. This DFS is **iterative with an explicit heap stack**, *not* call recursion: the Analyzer benchmarks graphs with tens of thousands of vertices, where a recursive DFS would nest ~V deep and overflow the (1 MB on Windows) call stack. Each stack frame remembers how far a vertex's out-edges have been scanned, so descending into a child and resuming the parent reproduces the exact recursive trace order.",
                "",
                "```cpp",
                "struct frame { vertex u; std::size_t i; };   // vertex + next out-edge",
                "std::vector<frame> stack;",
                "auto enter = [&](vertex u) {",
                "  seen[u] = 1;",
                "  trace({evt::discover_vertex, u});",
                "  trace({evt::visit_vertex, u});",
                "  stack.push_back({u, 0});",
                "};",
                "enter(src);",
                "while (!stack.empty()) {",
                "  const vertex u = stack.back().u;",
                "  const auto& edges = g.out(u);",
                "  if (stack.back().i < edges.size()) {",
                "    const edge<W>& e = edges[stack.back().i];",
                "    ++stack.back().i;                 // advance BEFORE enter() (may realloc)",
                "    trace({evt::examine_edge, u, e.to});",
                "    if (seen[e.to] == 0) { parent[e.to] = u; trace({evt::tree_edge, u, e.to}); enter(e.to); }",
                "    else trace({evt::skip_edge, u, e.to});",
                "  } else { seen[u] = 2; trace({evt::finish_vertex, u}); stack.pop_back(); }",
                "}",
                "```"
            ])
        },
        {
            id: "dijkstra", category: "Algorithms", glyph: "🛰️", title: "Dijkstra",
            summary: "Single-source shortest paths over non-negative weights, with a binary heap.",
            complexity: "O((V + E) log V)",
            props: ["shortest path", "weighted", "≥0 weights", "binary heap"],
            source: "core/modules/short_paths/dijkstra.ixx → core/include/ga/short_paths/dijkstra.hpp",
            related: { visualize: "Dijkstra", benchmark: "Dijkstra" },
            references: [
                { title: "Dijkstra's algorithm (Wikipedia)", url: "https://en.wikipedia.org/wiki/Dijkstra%27s_algorithm" }
            ],
            body: md([
                "## Idea",
                "Greedily settle the closest unsettled vertex, then relax its outgoing edges. Because weights are non-negative, once a vertex is removed from the frontier with the smallest tentative distance, that distance is final.",
                "",
                "## Complexity",
                "- Time: **O((V + E) log V)** with a binary heap.  Space: **O(V)**.",
                "- Requires **non-negative** weights (use Bellman–Ford otherwise).",
                "",
                "## Implementation in this project",
                "Source: `core/modules/short_paths/dijkstra.ixx`. The frontier is a **binary-heap** `std::priority_queue` of `(distance, vertex)` with `std::greater` (a min-heap). Settled vertices are skipped as *stale* heap entries instead of using decrease-key. `relax_edge` carries the new distance in `step.value`.",
                "",
                "```cpp",
                "using node = std::pair<W, vertex>;              // (distance, vertex)",
                "std::priority_queue<node, std::vector<node>, std::greater<node>> pq;",
                "dist[src] = 0; pq.push({0, src});",
                "while (!pq.empty()) {",
                "  const auto [d, u] = pq.top(); pq.pop();",
                "  if (settled[u]) continue;                    // stale heap entry",
                "  settled[u] = 1; trace({evt::visit_vertex, u, nil, (double)d});",
                "  for (const auto& e : g.out(u)) {",
                "    if (!settled[e.to] && dist[u] + e.weight < dist[e.to]) {",
                "      dist[e.to] = dist[u] + e.weight; par[e.to] = u;",
                "      pq.push({dist[e.to], e.to});",
                "      trace({evt::relax_edge, u, e.to, (double)dist[e.to]});",
                "    } else trace({evt::skip_edge, u, e.to});",
                "  }",
                "}",
                "```",
                "",
                "See the **Binary-heap priority queue** topic for the structure itself."
            ])
        },
        {
            id: "bellman-ford", category: "Algorithms", glyph: "➖", title: "Bellman–Ford",
            summary: "Shortest paths that tolerate negative weights and detect negative cycles.",
            complexity: "O(V · E)",
            props: ["shortest path", "weighted", "negative ok", "cycle detection"],
            source: "core/modules/short_paths/bellman_ford.ixx → core/include/ga/short_paths/bellman_ford.hpp",
            related: { visualize: "Bellman-Ford", benchmark: "Bellman-Ford" },
            references: [
                { title: "Bellman–Ford algorithm (Wikipedia)", url: "https://en.wikipedia.org/wiki/Bellman%E2%80%93Ford_algorithm" }
            ],
            body: md([
                "## Idea",
                "Relax *every* edge, repeatedly. After **|V|−1** rounds all shortest paths are found (a simple path has at most |V|−1 edges). One more round that still improves a distance means a reachable **negative cycle**.",
                "",
                "## Complexity",
                "- Time: **O(V · E)**.  Space: **O(V)**.",
                "- Handles negative weights; slower than Dijkstra, so prefer Dijkstra when weights are ≥ 0.",
                "",
                "## Implementation in this project",
                "Source: `core/modules/short_paths/bellman_ford.ixx`. It stops early when a round changes nothing, emits a `message` step per round (so the Visualizer can label rounds), then does a final pass to set the `ok` negative-cycle flag.",
                "",
                "```cpp",
                "bool changed = true;",
                "for (std::size_t round = 0; round + 1 < g.order() && changed; ++round) {",
                "  changed = false;",
                "  trace(step{evt::message, nil, nil, (double)(round+1), \"round \" + std::to_string(round+1)});",
                "  for (vertex u : g.vertices()) {",
                "    if (dist[u] == inf) continue;",
                "    for (const auto& e : g.out(u))",
                "      if (dist[u] + e.weight < dist[e.to]) {",
                "        dist[e.to] = dist[u] + e.weight; par[e.to] = u; changed = true;",
                "        trace({evt::relax_edge, u, e.to, (double)dist[e.to]});",
                "      } else trace({evt::skip_edge, u, e.to});",
                "  }",
                "}",
                "// one more pass: any further improvement ⇒ reachable negative cycle ⇒ ok = false",
                "```"
            ])
        },
        {
            id: "kruskal", category: "Algorithms", glyph: "🌲", title: "Kruskal (MST)",
            summary: "Minimum spanning tree/forest by sorting edges and a union-find.",
            complexity: "O(E log E)",
            props: ["MST", "weighted", "union-find"],
            source: "core/modules/mst/kruskal.ixx → core/include/ga/mst/kruskal.hpp",
            related: { visualize: "Kruskal", benchmark: "Kruskal" },
            references: [
                { title: "Kruskal's algorithm (Wikipedia)", url: "https://en.wikipedia.org/wiki/Kruskal%27s_algorithm" }
            ],
            body: md([
                "## Idea",
                "Consider edges in ascending weight. Accept an edge if its endpoints are in different components (it joins two trees); reject it if they're already connected (it would close a cycle). The result is a minimum spanning tree — or a spanning *forest* on a disconnected graph.",
                "",
                "## Complexity",
                "- Time: **O(E log E)** dominated by the sort; the union-find is near-O(1) amortised per query.",
                "",
                "## Implementation in this project",
                "Source: `core/modules/mst/kruskal.ixx`. It collects one copy of each undirected edge (`e.from <= e.to`), sorts by weight, then uses a **union-find (disjoint-set) with path-halving and union-by-rank**:",
                "",
                "```cpp",
                "std::vector<vertex> parent(n); std::iota(parent.begin(), parent.end(), 0);",
                "std::vector<std::size_t> rnk(n, 0);",
                "auto find = [&](vertex x) {",
                "  while (parent[x] != x) { parent[x] = parent[parent[x]]; x = parent[x]; }  // path-halving",
                "  return x;",
                "};",
                "for (const auto& e : edges) {               // edges sorted by weight",
                "  const vertex ra = find(e.from), rb = find(e.to);",
                "  if (ra == rb) { trace({evt::skip_edge, e.from, e.to}); continue; }   // would cycle",
                "  if (rnk[ra] < rnk[rb]) parent[ra] = rb;",
                "  else if (rnk[rb] < rnk[ra]) parent[rb] = ra;",
                "  else { parent[rb] = ra; ++rnk[ra]; }      // union-by-rank",
                "  total += e.weight; trace({evt::tree_edge, e.from, e.to, (double)e.weight});",
                "}",
                "```",
                "",
                "The union-find is covered on its own in the **Disjoint-set union** topic."
            ])
        },
        {
            id: "prim", category: "Algorithms", glyph: "🌳", title: "Prim (MST)",
            summary: "Grow a minimum spanning tree from a seed using a min-heap keyed by edge weight.",
            complexity: "O((V + E) log V)",
            props: ["MST", "weighted", "binary heap"],
            source: "core/modules/mst/prim.ixx → core/include/ga/mst/prim.hpp",
            related: { visualize: "Prim", benchmark: "Prim" },
            references: [
                { title: "Prim's algorithm (Wikipedia)", url: "https://en.wikipedia.org/wiki/Prim%27s_algorithm" }
            ],
            body: md([
                "## Idea",
                "Start from one vertex and repeatedly add the cheapest edge crossing the cut between the growing tree and the rest, until every reachable vertex is in the tree.",
                "",
                "## Complexity",
                "- Time: **O((V + E) log V)** with a binary heap.  On a disconnected graph it spans only the seed's component.",
                "",
                "## Implementation in this project",
                "Source: `core/modules/mst/prim.ixx`. Structurally almost identical to Dijkstra, but the heap is keyed by the **edge weight** crossing the cut, not a cumulative distance. The tuple carries `(weight, to, from)` so the accepted edge can be reported.",
                "",
                "```cpp",
                "using node = std::tuple<W, vertex, vertex>;   // (weight, to, from)",
                "std::priority_queue<node, std::vector<node>, std::greater<node>> pq;",
                "pq.push({W{}, src, nil});",
                "while (!pq.empty()) {",
                "  const auto [w, u, from] = pq.top(); pq.pop();",
                "  if (inTree[u]) continue;                    // stale heap entry",
                "  inTree[u] = 1;",
                "  if (from != nil) { total += w; trace({evt::tree_edge, from, u, (double)w}); }",
                "  for (const auto& e : g.out(u))",
                "    if (!inTree[e.to]) pq.push({e.weight, e.to, u});",
                "}",
                "```"
            ])
        },

        // ---------------- Data structures ----------------
        {
            id: "graph", category: "Data structures", glyph: "🕸️", title: "Graph (adjacency list)",
            summary: "The index-based, weight-generic graph every algorithm runs on.",
            complexity: "",
            props: ["adjacency list", "directed or undirected", "generic weight"],
            source: "core/modules/graph/graph.ixx → core/include/ga/graph/graph.hpp",
            references: [
                { title: "Adjacency list (Wikipedia)", url: "https://en.wikipedia.org/wiki/Adjacency_list" }
            ],
            body: md([
                "## Idea",
                "Vertices are integers `0 … order()-1` (cheap array indices). Each vertex owns a vector of out-edges — an **adjacency list** — which is compact for the sparse graphs algorithms usually care about and gives O(degree) neighbour iteration.",
                "",
                "## Design",
                "- `vertex = std::size_t`; `nil` marks \"no vertex\".",
                "- An **undirected** edge is stored as the *pair of opposing directed half-edges*, so `out(u)` works uniformly for both graph kinds. That's why an undirected graph holds ~2·E edge records (relevant to the Analyzer's memory estimate).",
                "- Presentation data (labels, positions, colours) deliberately lives *outside* the core, in the Visualizer, keeping the core a pure computation layer.",
                "",
                "## Implementation in this project",
                "Source: `core/modules/graph/graph.ixx`.",
                "",
                "```cpp",
                "template <class W = double> struct edge { vertex from{}, to{}; W weight{1}; };",
                "",
                "template <class W = double> class graph {",
                "  void add_edge(vertex u, vertex v, W w = W{1}) {",
                "    adj_[u].push_back(edge<W>{u, v, w}); ++edge_count_;",
                "    if (!directed_ && u != v) adj_[v].push_back(edge<W>{v, u, w});  // both halves",
                "  }",
                "  const std::vector<edge<W>>& out(vertex u) const { return adj_[u]; }",
                "  std::size_t order() const noexcept { return adj_.size(); }   // |V|",
                "private:",
                "  std::vector<std::vector<edge<W>>> adj_;",
                "};",
                "```"
            ])
        },
        {
            id: "dsu", category: "Data structures", glyph: "🔗", title: "Disjoint-set union (union-find)",
            summary: "Near-O(1) \"are these in the same set?\" — powers Kruskal and component checks.",
            complexity: "≈ O(α(n)) amortised",
            props: ["union-find", "path-halving", "union-by-rank"],
            source: "core/modules/mst/kruskal.ixx (also studio/AnalyzerController.cpp::pickSource)",
            references: [
                { title: "Disjoint-set data structure (Wikipedia)", url: "https://en.wikipedia.org/wiki/Disjoint-set_data_structure" }
            ],
            body: md([
                "## Idea",
                "Maintain a partition of elements into disjoint sets with two operations: **find** (which set is x in?) and **union** (merge two sets). Represented as a forest where each element points at a parent and each set is a tree rooted at its representative.",
                "",
                "## Why it's fast",
                "Two optimisations make it almost constant time (inverse-Ackermann α(n), effectively ≤ 4):",
                "- **Path compression / halving** — `find` flattens the tree as it walks up.",
                "- **Union by rank** — attach the shorter tree under the taller.",
                "",
                "## Implementation in this project",
                "The studio uses union-find in two places. In Kruskal (`core/modules/mst/kruskal.ixx`) it decides whether an edge joins two components or closes a cycle (see the **Kruskal** topic). The Analyzer reuses the same idea in `AnalyzerController::pickSource` to find the largest connected component for a representative benchmark source:",
                "",
                "```cpp",
                "auto find = [&](std::size_t x) {",
                "  while (parent[x] != x) { parent[x] = parent[parent[x]]; x = parent[x]; }  // halving",
                "  return x;",
                "};",
                "// union every edge's endpoints ⇒ weakly-connected components",
                "std::size_t a = find(u), b = find(e.to);",
                "if (a != b) { if (sz[a] < sz[b]) std::swap(a, b); parent[b] = a; sz[a] += sz[b]; }",
                "```"
            ])
        },
        {
            id: "heap", category: "Data structures", glyph: "⛰️", title: "Binary-heap priority queue",
            summary: "The min-priority queue behind Dijkstra and Prim.",
            complexity: "push / pop O(log n)",
            props: ["binary heap", "std::priority_queue"],
            source: "std::priority_queue in short_paths/dijkstra.ixx and mst/prim.ixx",
            references: [
                { title: "Binary heap (Wikipedia)", url: "https://en.wikipedia.org/wiki/Binary_heap" }
            ],
            body: md([
                "## Idea",
                "A binary heap is a complete binary tree kept as a flat array where every parent is ≤ its children (min-heap). The minimum is at the root — O(1) to read, O(log n) to push or pop as the tree re-settles.",
                "",
                "## Implementation in this project",
                "Rather than a hand-rolled heap, the core uses the standard library's `std::priority_queue` with `std::greater` to make it a **min-heap**. Both Dijkstra and Prim avoid decrease-key by pushing a new entry and discarding **stale** entries when they pop (`if (settled[u]) continue;`):",
                "",
                "```cpp",
                "using node = std::pair<W, vertex>;              // Dijkstra: (distance, vertex)",
                "std::priority_queue<node, std::vector<node>, std::greater<node>> pq;",
                "// Prim uses std::tuple<W, vertex, vertex> — (edge weight, to, from)",
                "```",
                "",
                "This keeps the frontier correct at the cost of up to E heap entries — simpler than an indexed heap and plenty fast for the studio's graphs. See the **Dijkstra** and **Prim** topics for the full loops."
            ])
        },
        {
            id: "trace", category: "Data structures", glyph: "🎞️", title: "Trace / step event model",
            summary: "The instrumentation hook that lets the Visualizer animate any algorithm.",
            complexity: "",
            props: ["observer hook", "weight-agnostic"],
            source: "core/modules/graph/trace.ixx → core/include/ga/graph/trace.hpp",
            references: [],
            body: md([
                "## Idea",
                "Every algorithm takes an optional `tracer` callback and emits a `step` at each interesting moment — discovering a vertex, relaxing an edge, finishing, … With **no** tracer the algorithm is a plain, fast computation; **with** one, a UI (or a test) observes the run and animates it step by step. One mechanism, two uses.",
                "",
                "## Design",
                "The `step` is deliberately *weight-agnostic* — plain vertex ids plus a `double value` — so a single tracer type works for every algorithm. The Visualizer folds the step stream into per-step snapshots; the Analyzer swaps in a counting tracer to tally operations.",
                "",
                "## Implementation in this project",
                "Source: `core/modules/graph/trace.ixx`.",
                "",
                "```cpp",
                "enum class evt {",
                "  discover_vertex, visit_vertex, finish_vertex,",
                "  examine_edge, tree_edge, relax_edge, skip_edge, found_target, message",
                "};",
                "struct step {",
                "  evt kind;",
                "  vertex u = nil;     // the vertex, or an edge's source",
                "  vertex v = nil;     // an edge's target",
                "  double value = 0;   // e.g. the new distance on relax_edge",
                "  std::string note{};",
                "};",
                "using tracer = std::function<void(const step&)>;",
                "inline void ignore(const step&) {}   // default no-op",
                "```"
            ])
        },
        {
            id: "bench", category: "Data structures", glyph: "⏱️", title: "Benchmark harness",
            summary: "The timing, op-counting and peak-memory tools behind the Analyzer.",
            complexity: "",
            props: ["timing", "op counters", "peak memory"],
            source: "core/modules/bench/bench.ixx → core/include/ga/bench/bench.hpp",
            references: [],
            body: md([
                "## Idea",
                "A tiny, header-only harness so algorithms can be measured without pulling in Qt. Three independent tools: wall-clock timing, operation counting (via a tracer), and peak-heap tracking.",
                "",
                "## Implementation in this project",
                "Source: `core/modules/bench/bench.ixx`. `time_it` runs a callable `warmup` times untimed, then `runs` times timed, returning min/median/mean/σ. A timed run must use **no** tracer (recording steps would dominate the measurement); op counting is a *separate* untimed run with `count_into`.",
                "",
                "```cpp",
                "template <class Fn> result time_it(Fn&& fn, int runs = 5, int warmup = 1);",
                "struct counters { std::size_t discover_vertex, visit_vertex, /* … */ total; };",
                "tracer count_into(counters& c);   // tally each step kind",
                "namespace mem { void start(); void stop(); std::size_t peak_bytes(); }",
                "```",
                "",
                "The Analyzer wires all three together per (algorithm, size) cell — and `mem` is only armed by linking the global `operator new`/`delete` override in `studio/mem_tracker.cpp`."
            ])
        },

        // ---------------- Project ----------------
        {
            id: "modules", category: "Project", glyph: "🧱", title: "Modules → header twins",
            summary: "Why there's both a .ixx and a .hpp for every core file.",
            complexity: "",
            props: ["C++20 modules", "code generation"],
            source: "core/modules/**/*.ixx (source of truth) · scripts/gen_ga_hpp.py · core/include/ga/**/*.hpp",
            references: [
                { title: "C++20 modules (cppreference)", url: "https://en.cppreference.com/w/cpp/language/modules" }
            ],
            body: md([
                "## Why two files per algorithm",
                "The graph core is written as **C++20 modules** (`.ixx`) — the single source of truth, built by the MSVC solution. But the Qt/MinGW Studio build and the module-less tests can't rely on modules / `import std`, so each `.ixx` has a generated **header-only twin** under `core/include/ga/**`.",
                "",
                "## How the twin is made",
                "`scripts/gen_ga_hpp.py` performs a mechanical transform per file: drop the `module;` marker and `export module …;` line, turn `import :part;` into the matching `#include`, strip a leading `export`, and prepend a \"GENERATED — DO NOT EDIT\" banner.",
                "",
                "```text",
                "core/modules/basic_algo/dfs.ixx   --gen_ga_hpp.py-->   core/include/ga/basic_algo/dfs.hpp",
                "```",
                "",
                "## What this means for you",
                "- **Edit the `.ixx`**, never the `.hpp` — then run `py -I scripts/gen_ga_hpp.py` to regenerate (or `--check` in CI to catch a stale twin).",
                "- Everything you read in these articles is the real code from the `.ixx`; the `.hpp` is a verbatim, module-free mirror of it."
            ])
        }
    ]
}
