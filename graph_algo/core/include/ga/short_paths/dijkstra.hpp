#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of dijkstra.ixx (the C++20 module), produced by
// scripts/gen_ga_hpp.py. The .ixx is the source of truth: edit it and re-run
//   py -I scripts/gen_ga_hpp.py
// This header lets the Qt/MinGW visualizer and the tests use the ga core
// without C++20 modules / `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "ga core requires a C++20 compiler (GCC >= 11)."
#endif

// Dijkstra's single-source shortest paths over non-negative edge weights.
//
// Returns the distance from src to every vertex (unreachable == infinity) and,
// via the out-parameter `parent`, the shortest-path tree. Emits trace steps —
// visit_vertex when a vertex is settled, relax_edge (with the new distance in
// step.value) when a shorter path is found — so a visualizer can animate it.

#include <algorithm>
#include <bit>
#include <chrono>
#include <cmath>
#include <compare>
#include <concepts>
#include <cstddef>
#include <cstdint>
#include <functional>
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
  std::vector<weight_t<G>> dijkstra(const G& g, vertex src,
    std::vector<vertex>* parent = nullptr,
    const tracer& trace = ignore) {
    using W = weight_t<G>;
    constexpr W inf = std::numeric_limits<W>::max();
    std::vector<W> dist(g.order(), inf);
    std::vector<char> settled(g.order(), 0);
    std::vector<vertex> par(g.order(), nil);

    using node = std::pair<W, vertex>;              // (distance, vertex)
    std::priority_queue<node, std::vector<node>, std::greater<node>> pq;

    dist[src] = W{0};
    par[src] = src;
    pq.push({W{0}, src});
    trace({evt::discover_vertex, src, nil, 0.0});

    while(!pq.empty()) {
      const auto [d, u] = pq.top();
      pq.pop();
      if(settled[u]) continue;                   // stale heap entry
      settled[u] = 1;
      trace({evt::visit_vertex, u, nil, static_cast<double>(d)});

      for(const auto& e : g.out(u)) {
        trace({evt::examine_edge, u, e.to});
        if(!settled[e.to] && dist[u] != inf && dist[u] + e.weight < dist[e.to]) {
          dist[e.to] = dist[u] + e.weight;
          par[e.to] = u;
          pq.push({dist[e.to], e.to});
          trace({evt::relax_edge, u, e.to, static_cast<double>(dist[e.to])});
        }
        else {
          trace({evt::skip_edge, u, e.to});
        }
      }
      trace({evt::finish_vertex, u, nil, static_cast<double>(d)});
    }

    if(parent) *parent = std::move(par);
    return dist;
  }
}  // namespace ga
