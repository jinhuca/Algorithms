#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of gen.ixx (the C++20 module), produced by
// scripts/gen_ga_hpp.py. The .ixx is the source of truth: edit it and re-run
//   py -I scripts/gen_ga_hpp.py
// This header lets the Qt/MinGW visualizer and the tests use the ga core
// without C++20 modules / `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "ga core requires a C++20 compiler (GCC >= 11)."
#endif

// ga::gen — synthetic graph generators for benchmarking (Qt-free).
//
// Every generator is deterministic for a fixed seed, so benchmark runs are
// reproducible and comparable across machines. They build ga::graph<W> only and
// emit no trace — generation is the setup, not the thing being measured.
//
// Weights: pass wmin == wmax (the default, 1) for an unweighted graph, or a
// range [wmin, wmax] for uniform random weights (for Dijkstra / MST workloads).
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

namespace ga {
namespace gen {

  using rng_t = std::mt19937_64;

  // A non-zero default seed (the splitmix64 / golden-ratio constant) so that
  // seed 0 still produces a fixed, reproducible graph.
  inline rng_t make_rng(std::uint64_t seed) {
    return rng_t(seed ? seed : 0x9E3779B97F4A7C15ull);
  }

  // One edge weight: the constant wmin when wmax <= wmin, else uniform in
  // [wmin, wmax] (sampled as double, cast back to W).
  template <typename W>
  inline W sample_weight(rng_t& r, W wmin, W wmax) {
    if (!(wmax > wmin)) return wmin;
    std::uniform_real_distribution<double> d(static_cast<double>(wmin),
                                             static_cast<double>(wmax));
    return static_cast<W>(d(r));
  }

  // Complete graph K_n: every distinct pair connected once (undirected) or in
  // both directions (directed). Dense — Θ(n²) edges; the stress case.
  template <typename W = double>
  graph<W> complete(std::size_t n, bool directed = false,
                    W wmin = W{1}, W wmax = W{1}, std::uint64_t seed = 0) {
    graph<W> g(n, directed);
    rng_t r = make_rng(seed);
    for (vertex u = 0; u < n; ++u)
      for (vertex v = (directed ? vertex{0} : u + 1); v < n; ++v)
        if (u != v) g.add_edge(u, v, sample_weight(r, wmin, wmax));
    return g;
  }

  // 4-neighbour grid lattice, rows × cols, undirected. Vertex (r, c) has id
  // r*cols + c. Predictable structure and diameter — clean for scaling curves.
  template <typename W = double>
  graph<W> grid(std::size_t rows, std::size_t cols,
                W wmin = W{1}, W wmax = W{1}, std::uint64_t seed = 0) {
    graph<W> g(rows * cols, false);
    rng_t r = make_rng(seed);
    auto id = [cols](std::size_t rr, std::size_t cc) -> vertex { return rr * cols + cc; };
    for (std::size_t rr = 0; rr < rows; ++rr)
      for (std::size_t cc = 0; cc < cols; ++cc) {
        if (cc + 1 < cols) g.add_edge(id(rr, cc), id(rr, cc + 1), sample_weight(r, wmin, wmax));
        if (rr + 1 < rows) g.add_edge(id(rr, cc), id(rr + 1, cc), sample_weight(r, wmin, wmax));
      }
    return g;
  }

  // Erdős–Rényi G(n, m): n vertices and m distinct random edges (no self-loops,
  // no parallels). Rejection sampling — intended for sparse m (m ≪ n²); m is
  // clamped to the maximum possible edge count.
  template <typename W = double>
  graph<W> random_gnm(std::size_t n, std::size_t m, bool directed = false,
                      std::uint64_t seed = 0, W wmin = W{1}, W wmax = W{1}) {
    graph<W> g(n, directed);
    if (n < 2) return g;
    rng_t r = make_rng(seed);
    const long double maxE = directed ? (long double)n * (n - 1)
                                       : (long double)n * (n - 1) / 2;
    if ((long double)m > maxE) m = static_cast<std::size_t>(maxE);
    std::unordered_set<unsigned long long> used;
    used.reserve(m * 2);
    std::uniform_int_distribution<std::size_t> pick(0, n - 1);
    while (used.size() < m) {
      vertex a = pick(r), b = pick(r);
      if (a == b) continue;
      if (!directed && a > b) std::swap(a, b);
      const unsigned long long key = (unsigned long long)a * n + b;
      if (used.insert(key).second)
        g.add_edge(a, b, sample_weight(r, wmin, wmax));
    }
    return g;
  }

  // Barabási–Albert scale-free: start from a clique of m seed vertices, then each
  // new vertex attaches to m existing vertices chosen with probability ∝ degree
  // (preferential attachment). Yields a few high-degree hubs, like real networks.
  template <typename W = double>
  graph<W> scale_free(std::size_t n, std::size_t m, std::uint64_t seed = 0,
                      W wmin = W{1}, W wmax = W{1}) {
    if (m < 1) m = 1;
    if (n <= m) n = m + 1;
    graph<W> g(n, false);
    rng_t r = make_rng(seed);
    std::vector<vertex> repeated;                 // each vertex appears once per unit of degree
    repeated.reserve(n * m * 2);
    for (vertex i = 0; i < m; ++i)                // seed clique
      for (vertex j = i + 1; j < m; ++j) {
        g.add_edge(i, j, sample_weight(r, wmin, wmax));
        repeated.push_back(i);
        repeated.push_back(j);
      }
    if (repeated.empty()) repeated.push_back(0);  // m == 1: seed the target pool
    for (vertex v = m; v < n; ++v) {
      std::unordered_set<vertex> targets;
      while (targets.size() < m) {
        std::uniform_int_distribution<std::size_t> pick(0, repeated.size() - 1);
        const vertex t = repeated[pick(r)];
        if (t != v) targets.insert(t);
      }
      for (vertex t : targets) {
        g.add_edge(v, t, sample_weight(r, wmin, wmax));
        repeated.push_back(v);
        repeated.push_back(t);
      }
    }
    return g;
  }

}  // namespace gen
}  // namespace ga
