// Minimal dependency-free tests for the graph core (no test framework so it
// builds anywhere). Exits non-zero on the first failed check.

#include <cassert>
#include <cstdio>
#include <vector>

#include <ga/basic_algo/bfs.hpp>
#include <ga/basic_algo/dfs.hpp>
#include <ga/graph/graph.hpp>
#include <ga/mst/kruskal.hpp>
#include <ga/mst/prim.hpp>
#include <ga/short_paths/bellman_ford.hpp>
#include <ga/short_paths/dijkstra.hpp>

// The concrete ga::graph satisfies the graph_like concept the algorithms require,
// for any weight type; weight_t recovers the edge weight type.
static_assert(ga::graph_like<ga::graph<double>>);
static_assert(ga::graph_like<ga::graph<int>>);
static_assert(std::is_same_v<ga::weight_t<ga::graph<int>>, int>);

static int failures = 0;
#define CHECK(cond)                                                       \
    do {                                                                  \
        if (!(cond)) {                                                    \
            std::printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, #cond);   \
            ++failures;                                                   \
        }                                                                 \
    } while (0)

int main() {
    // A small weighted, undirected graph:
    //   0 --1-- 1 --1-- 2
    //   |               |
    //   4               1
    //    \--- 3 ---2----/
    ga::graph<int> g(4, /*directed=*/false);
    g.add_edge(0, 1, 1);
    g.add_edge(1, 2, 1);
    g.add_edge(0, 3, 4);
    g.add_edge(2, 3, 2);

    CHECK(g.order() == 4);
    CHECK(g.size() == 4);
    CHECK(!g.directed());

    // --- BFS from 0: tree distances by levels, and the tracer fires. ---
    int visited = 0;
    auto parent = ga::bfs(g, 0, [&](const ga::step& s) {
        if (s.kind == ga::evt::visit_vertex) ++visited;
    });
    CHECK(visited == 4);                 // every vertex visited once
    CHECK(parent[0] == 0);               // root
    CHECK(parent[1] == 0);
    CHECK(parent[2] == 1);
    CHECK(parent[3] == 0);               // BFS ignores weights: 0->3 directly

    // --- Dijkstra from 0: shortest paths respect weights. ---
    std::vector<ga::vertex> dpar;
    int relaxations = 0;
    auto dist = ga::dijkstra(g, 0, &dpar, [&](const ga::step& s) {
        if (s.kind == ga::evt::relax_edge) ++relaxations;
    });
    CHECK(dist[0] == 0);
    CHECK(dist[1] == 1);
    CHECK(dist[2] == 2);
    CHECK(dist[3] == 4);                 // 0->3 (4) beats 0->1->2->3 (1+1+2=4)? tie -> 4
    CHECK(relaxations >= 3);             // at least one relax per reached vertex
    CHECK(dpar[2] == 1);                 // shortest path to 2 goes via 1

    // --- DFS from 0: every vertex reached, valid parent tree, tracer fires. ---
    int finished = 0;
    auto fpar = ga::dfs(g, 0, [&](const ga::step& s) {
        if (s.kind == ga::evt::finish_vertex) ++finished;
    });
    CHECK(finished == 4);
    CHECK(fpar[0] == 0);
    for (int v = 1; v < 4; ++v) CHECK(fpar[v] != ga::nil);   // all reachable

    // --- Bellman-Ford matches Dijkstra on non-negative weights. ---
    std::vector<ga::vertex> bpar;
    bool ok = false;
    auto bdist = ga::bellman_ford(g, 0, &bpar, &ok);
    CHECK(ok);                           // no negative cycle
    CHECK(bdist[0] == 0);
    CHECK(bdist[1] == 1);
    CHECK(bdist[2] == 2);
    CHECK(bdist[3] == 4);

    // --- Kruskal MST: picks 0-1(1), 1-2(1), 2-3(2); rejects 0-3(4). ---
    int kTreeEdges = 0;
    auto kw = ga::kruskal(g, [&](const ga::step& s) {
        if (s.kind == ga::evt::tree_edge) ++kTreeEdges;
    });
    CHECK(kw == 4);                      // total MST weight
    CHECK(kTreeEdges == 3);              // n-1 edges for a connected graph

    // --- Prim MST from 0: same tree / weight, grown from the source. ---
    int pTreeEdges = 0;
    auto pw = ga::prim(g, 0, [&](const ga::step& s) {
        if (s.kind == ga::evt::tree_edge) ++pTreeEdges;
    });
    CHECK(pw == 4);
    CHECK(pTreeEdges == 3);

    if (failures == 0) std::printf("OK: all graph core checks passed\n");
    return failures == 0 ? 0 : 1;
}
