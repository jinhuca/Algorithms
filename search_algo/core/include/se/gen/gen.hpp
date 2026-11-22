#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of gen.ixx (the C++20 module), produced by
// scripts/gen_se_hpp.py. The .ixx is the source of truth: edit it and re-run
//   py -I scripts/gen_se_hpp.py
// This header lets the Qt/MinGW app and the tests use the se core without
// C++20 modules / `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "se core requires a C++20 compiler (GCC >= 11)."
#endif

// se::gen — synthetic array generators + target pickers for benchmarking + demos
// (Qt-free), the search-studio analogue of sa::gen. Every generator is deterministic
// for a fixed seed, so benchmark runs are reproducible and comparable across machines.
//
// The sorted searches need an ordered array, so most shapes return ascending data; the
// *distribution* (evenly spaced vs clustered vs duplicate-heavy) is what separates
// binary from interpolation search. A search also needs a TARGET: present_target()
// picks an element actually in the array at a chosen fraction (for best/worst position
// studies), and missing_target() returns a value guaranteed absent, which forces a
// search to its full depth.

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <random>
#include <vector>

namespace se {
namespace gen {

  using rng_t = std::mt19937_64;

  // A non-zero default seed (the splitmix64 / golden-ratio constant) so that seed 0
  // still produces a fixed, reproducible array.
  inline rng_t make_rng(std::uint64_t seed) {
    return rng_t(seed ? seed : 0x9E3779B97F4A7C15ull);
  }

  // Ascending, evenly spaced across [lo, hi] — the ideal uniform input where
  // interpolation search shines (O(log log n)).
  inline std::vector<double> sorted(std::size_t n, double lo = 1.0, double hi = 1000.0) {
    std::vector<double> v(n);
    const double span = (n > 1) ? (hi - lo) / static_cast<double>(n - 1) : 0.0;
    for (std::size_t i = 0; i < n; ++i) v[i] = lo + span * static_cast<double>(i);
    return v;
  }

  // Uniform random values in [lo, hi], then sorted — ascending but unevenly spaced, so
  // interpolation search's guesses are off and it does more probes than on sorted().
  inline std::vector<double> random_sorted(std::size_t n, std::uint64_t seed = 0,
                                           double lo = 1.0, double hi = 1000.0) {
    std::vector<double> v(n);
    rng_t r = make_rng(seed);
    std::uniform_real_distribution<double> d(lo, hi);
    for (auto& x : v) x = d(r);
    std::sort(v.begin(), v.end());
    return v;
  }

  // Sorted with only `k` distinct values (many duplicates) — exercises equal-key
  // windows and "find any matching element" behaviour.
  inline std::vector<double> few_unique_sorted(std::size_t n, std::size_t k = 5,
                                               std::uint64_t seed = 0,
                                               double lo = 1.0, double hi = 1000.0) {
    std::vector<double> v(n);
    if (k < 1) k = 1;
    rng_t r = make_rng(seed);
    std::vector<double> levels(k);
    const double span = (k > 1) ? (hi - lo) / static_cast<double>(k - 1) : 0.0;
    for (std::size_t i = 0; i < k; ++i) levels[i] = lo + span * static_cast<double>(i);
    std::uniform_int_distribution<std::size_t> pick(0, k - 1);
    for (auto& x : v) x = levels[pick(r)];
    std::sort(v.begin(), v.end());
    return v;
  }

  // Sorted normally-distributed values (clamped to [lo, hi]) — a clustered, non-uniform
  // shape that is the worst case for interpolation search.
  inline std::vector<double> gaussian_sorted(std::size_t n, std::uint64_t seed = 0,
                                             double lo = 1.0, double hi = 1000.0) {
    std::vector<double> v(n);
    rng_t r = make_rng(seed);
    const double mean = 0.5 * (lo + hi);
    const double stddev = (hi - lo) / 6.0;      // ~99.7% land inside [lo, hi]
    std::normal_distribution<double> d(mean, stddev);
    for (auto& x : v) x = std::clamp(d(r), lo, hi);
    std::sort(v.begin(), v.end());
    return v;
  }

  // Unsorted uniform random — for the sequential searches (linear / sentinel), which
  // don't need order.
  inline std::vector<double> unsorted_random(std::size_t n, std::uint64_t seed = 0,
                                             double lo = 1.0, double hi = 1000.0) {
    std::vector<double> v(n);
    rng_t r = make_rng(seed);
    std::uniform_real_distribution<double> d(lo, hi);
    for (auto& x : v) x = d(r);
    return v;
  }

  // An element actually present in `v`, at position round(frac*(n-1)) — frac=0 is the
  // front (best case for linear / exponential), 1 the back, 0.5 the middle. Returns 0
  // for an empty array.
  inline double present_target(const std::vector<double>& v, double frac = 0.5) {
    if (v.empty()) return 0.0;
    if (frac < 0.0) frac = 0.0;
    if (frac > 1.0) frac = 1.0;
    const std::size_t idx =
        static_cast<std::size_t>(frac * static_cast<double>(v.size() - 1) + 0.5);
    return v[idx];
  }

  // A value guaranteed NOT in `v` (one past the maximum) — forces a search to its full
  // depth / a full linear scan (the absent-key worst case). Returns 0 for empty.
  inline double missing_target(const std::vector<double>& v) {
    if (v.empty()) return 0.0;
    return *std::max_element(v.begin(), v.end()) + 1.0;
  }

}  // namespace gen
}  // namespace se
