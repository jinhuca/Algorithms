module;

// Breadth-first search over an unweighted graph.
//
// Returns the BFS tree as a parent array (parent[src] == src; parent[v] == nil
// for vertices unreachable from src). Emits trace steps so a visualizer can
// animate the frontier expanding level by level.

export module ga.basic_algo.bfs;

import std;
import ga.graph;
import ga.trace;

export namespace ga {
  template <graph_like G>
  std::vector<vertex> bfs(const G& g, vertex src, const tracer& trace = ignore) {
    std::vector<vertex> parent(g.order(), nil);
    std::vector<char> seen(g.order(), 0);
    std::queue<vertex> q;

    seen[src] = 1;
    parent[src] = src;
    q.push(src);
    trace({evt::discover_vertex, src});

    while(!q.empty()) {
      const vertex u = q.front();
      q.pop();
      trace({evt::visit_vertex, u});

      for(const auto& e : g.out(u)) {
        trace({evt::examine_edge, u, e.to});
        if(!seen[e.to]) {
          seen[e.to] = 1;
          parent[e.to] = u;
          q.push(e.to);
          trace({evt::tree_edge, u, e.to});
          trace({evt::discover_vertex, e.to});
        }
        else {
          trace({evt::skip_edge, u, e.to});
        }
      }
      trace({evt::finish_vertex, u});
    }
    return parent;
  }
}  // namespace ga
