#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of bfs.ixx (the C++20 module), produced by
// scripts/gen_ga_hpp.py. The .ixx is the source of truth: edit it and re-run
//   py -I scripts/gen_ga_hpp.py
// This header lets the Qt/MinGW visualizer and the tests use the ga core
// without C++20 modules / `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "ga core requires a C++20 compiler (GCC >= 11)."
#endif

// Breadth-first search over an unweighted graph.
//
// Returns the BFS tree as a parent array (parent[src] == src; parent[v] == nil
// for vertices unreachable from src). Emits trace steps so a visualizer can
// animate the frontier expanding level by level.

#include <queue>
#include <vector>

#include "../graph/graph.hpp"
#include "../graph/trace.hpp"

namespace ga {

  template <class W>
  std::vector<vertex> bfs(const graph<W>& g, vertex src, const tracer& trace = ignore) {
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
