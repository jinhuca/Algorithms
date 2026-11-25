#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of prim.ixx (the C++20 module), produced by
//   py -I scripts/gen_hpp.py --project graph_algo --ns ga
// The .ixx is the source of truth: edit it and re-run the generator. This header
// lets the Qt/MinGW app and the tests use the ga core without C++20 modules /
// `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "ga core requires a C++20 compiler (GCC >= 11)."
#endif

// Prim's minimum spanning tree, grown from a start vertex.
//
// Repeatedly adds the minimum-weight edge crossing the cut between the tree and
// the rest, using a min-priority queue keyed by EDGE weight (not a cumulative
// distance — that's the only structural difference from Dijkstra). Emits trace
// steps (discover / visit / finish vertex, and tree_edge for the connecting
// edge) so a visualizer can animate the tree growing. Returns the total weight;
// on a disconnected graph it spans only the start vertex's component.

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
  weight_t<G> prim(const G& g, vertex src, const tracer& trace = ignore) {
    using W = weight_t<G>;
    const std::size_t n = g.order();
    if(n == 0 || src >= n) return W{};

    std::vector<char> inTree(n, 0);
    // (weight, to, from) — min-heap by weight; `from` is nil for the seed.
    using node = std::tuple<W, vertex, vertex>;
    std::priority_queue<node, std::vector<node>, std::greater<node>> pq;

    pq.push({W{}, src, nil});
    trace({evt::discover_vertex, src});

    W total{};
    while(!pq.empty()) {
      const auto [w, u, from] = pq.top();
      pq.pop();
      if(inTree[u]) continue;                 // stale heap entry
      inTree[u] = 1;
      trace({evt::visit_vertex, u});
      if(from != nil) {
        total += w;
        trace({evt::tree_edge, from, u, static_cast<double>(w)});
      }
      for(const auto& e : g.out(u)) {
        trace({evt::examine_edge, u, e.to});
        if(!inTree[e.to]) {
          pq.push({e.weight, e.to, u});
          trace({evt::discover_vertex, e.to});
        }
        else {
          trace({evt::skip_edge, u, e.to});
        }
      }
      trace({evt::finish_vertex, u});
    }
    return total;
  }
}  // namespace ga
