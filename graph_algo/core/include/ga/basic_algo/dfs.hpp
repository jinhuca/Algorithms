#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of dfs.ixx (the C++20 module), produced by
//   py -I scripts/gen_hpp.py --project graph_algo --ns ga
// The .ixx is the source of truth: edit it and re-run the generator. This header
// lets the Qt/MinGW app and the tests use the ga core without C++20 modules /
// `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "ga core requires a C++20 compiler (GCC >= 11)."
#endif

// Depth-first search from a source vertex.
//
// Returns the DFS tree as a parent array (parent[src] == src). Emits trace
// steps so a visualizer can show the recursion: every vertex on the current
// call stack is "current", descendants that have returned are "settled".
//
// Uses an EXPLICIT stack rather than call recursion: the Analyzer benchmarks
// graphs with tens of thousands of vertices, where a recursive DFS can nest ~V
// deep and overflow the (1 MB on Windows) call stack, crashing the process. The
// explicit stack grows on the heap instead. Each frame remembers how far u's
// out-edges have been scanned, so descending into a child and later resuming the
// parent reproduces the recursive trace order exactly.
#include <algorithm>
#include <bit>
#include <chrono>
#include <cmath>
#include <compare>
#include <concepts>
#include <cstddef>
#include <cstdint>
#include <functional>
#include <iterator>
#include <limits>
#include <map>
#include <numeric>
#include <queue>
#include <random>
#include <ranges>
#include <string>
#include <tuple>
#include <type_traits>
#include <unordered_set>
#include <utility>
#include <vector>

#include "../graph/graph.hpp"
#include "../graph/trace.hpp"

namespace ga {

  template <graph_like G>
  std::vector<vertex> dfs(const G& g, vertex src, const tracer& trace = ignore) {
    std::vector<vertex> parent(g.order(), nil);
    std::vector<char> seen(g.order(), 0);   // 0 = unseen, 1 = on stack, 2 = finished

    struct frame { vertex u; std::size_t i; };   // vertex + next out-edge to scan
    std::vector<frame> stack;

    // Mirror the recursive descent's entry steps: discover, then visit, then push.
    auto enter = [&](vertex u) {
      seen[u] = 1;
      trace({evt::discover_vertex, u});
      trace({evt::visit_vertex, u});
      stack.push_back({u, 0});
    };

    parent[src] = src;
    enter(src);
    while(!stack.empty()) {
      const vertex u = stack.back().u;
      const auto& edges = g.out(u);
      if(stack.back().i < edges.size()) {
        const auto& e = edges[stack.back().i];
        ++stack.back().i;                   // advance BEFORE enter() (it may realloc `stack`)
        trace({evt::examine_edge, u, e.to});
        if(seen[e.to] == 0) {
          parent[e.to] = u;
          trace({evt::tree_edge, u, e.to});
          enter(e.to);                      // "recurse": resumes u when this subtree finishes
        }
        else {
          trace({evt::skip_edge, u, e.to});   // back / cross / forward edge
        }
      }
      else {                                // all of u's edges scanned — u is done
        seen[u] = 2;
        trace({evt::finish_vertex, u});
        stack.pop_back();
      }
    }
    return parent;
  }

}  // namespace ga
