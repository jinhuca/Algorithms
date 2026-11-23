import std;

// Module-based smoke test for the ga core, built by graph_algo.slnx. Unlike the
// header-based core/tests/test_core.cpp (which the MinGW/CMake build compiles
// against the generated .hpp), this one `import`s the C++20 modules directly, so
// it exercises the real module build (core + family static libs via references).
import ga.graph;
import ga.trace;
import ga.basic_algo.bfs;
import ga.basic_algo.dfs;
import ga.short_paths.dijkstra;
import ga.short_paths.bellman_ford;
import ga.mst.kruskal;
import ga.mst.prim;

static int failures = 0;
#define CHECK(cond)                                                       \
    do {                                                                  \
        if (!(cond)) {                                                    \
            std::printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, #cond);   \
            ++failures;                                                   \
        }                                                                 \
    } while (0)

int main() {
  // Small weighted, undirected graph:  0 --1-- 1 --1-- 2 ,  0 --4-- 2
  ga::graph<double> g(3);
  g.add_edge(0, 1, 1.0);
  g.add_edge(1, 2, 1.0);
  g.add_edge(0, 2, 4.0);

  // BFS from 0 reaches every vertex; the tree roots at the source.
  const std::vector<ga::vertex> bt = ga::bfs(g, 0);
  CHECK(bt[0] == 0);
  CHECK(bt[1] != ga::nil);
  CHECK(bt[2] != ga::nil);

  // DFS from 0 reaches every vertex too.
  const std::vector<ga::vertex> dt = ga::dfs(g, 0);
  CHECK(dt[1] != ga::nil);
  CHECK(dt[2] != ga::nil);

  // Dijkstra: shortest 0->2 is 0-1-2 (cost 2), not the direct edge (cost 4).
  std::vector<ga::vertex> dpar;
  const std::vector<double> dist = ga::dijkstra(g, 0, &dpar);
  CHECK(dist[0] == 0.0);
  CHECK(dist[1] == 1.0);
  CHECK(dist[2] == 2.0);

  // Bellman-Ford agrees and reports no negative cycle.
  std::vector<ga::vertex> bpar;
  bool ok = false;
  const std::vector<double> bdist = ga::bellman_ford(g, 0, &bpar, &ok);
  CHECK(ok);
  CHECK(bdist[2] == 2.0);

  // MST: tree is 0-1(1) + 1-2(1) = weight 2; the 0-2(4) edge is rejected.
  CHECK(ga::kruskal(g) == 2.0);
  CHECK(ga::prim(g, 0) == 2.0);

  if(failures == 0) std::printf("ga module smoke test: OK\n");
  return failures == 0 ? 0 : 1;
}
