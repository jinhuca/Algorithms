module;

// sa::gen — synthetic array generators for benchmarking + demos (Qt-free), the
// sort-algo analogue of ga::gen. Every generator is deterministic for a fixed
// seed, so benchmark runs are reproducible and comparable across machines. They
// build a std::vector<double> (bar heights) and emit no trace — generation is the
// setup, not the thing being measured.
//
// The input *distribution* is what makes a simple sort fast or slow (already-sorted
// vs reversed vs nearly-sorted vs few-unique), so each shape is its own generator.

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <random>
#include <vector>

export module sa.gen;

export namespace sa {
namespace gen {

  using rng_t = std::mt19937_64;

  // A non-zero default seed (the splitmix64 / golden-ratio constant) so that seed 0
  // still produces a fixed, reproducible array.
  inline rng_t make_rng(std::uint64_t seed) {
    return rng_t(seed ? seed : 0x9E3779B97F4A7C15ull);
  }

  // Uniform random values in [lo, hi]. The general-purpose "shuffled" workload.
  inline std::vector<double> random(std::size_t n, std::uint64_t seed = 0,
                                    double lo = 1.0, double hi = 1000.0) {
    std::vector<double> v(n);
    rng_t r = make_rng(seed);
    std::uniform_real_distribution<double> d(lo, hi);
    for (auto& x : v) x = d(r);
    return v;
  }

  // Already ascending, evenly spaced across [lo, hi] — the best case for the
  // adaptive sorts (bubble / cocktail / insertion exit in ~O(n)).
  inline std::vector<double> sorted(std::size_t n, double lo = 1.0, double hi = 1000.0) {
    std::vector<double> v(n);
    const double span = (n > 1) ? (hi - lo) / static_cast<double>(n - 1) : 0.0;
    for (std::size_t i = 0; i < n; ++i) v[i] = lo + span * static_cast<double>(i);
    return v;
  }

  // Strictly descending — the worst case for bubble/insertion (every pair inverts).
  inline std::vector<double> reversed(std::size_t n, double lo = 1.0, double hi = 1000.0) {
    std::vector<double> v = sorted(n, lo, hi);
    std::reverse(v.begin(), v.end());
    return v;
  }

  // Sorted, then perturbed by `swaps` random adjacent-ish transpositions — the near-
  // best case that rewards adaptive sorts. `swaps` defaults to ~5% of n.
  inline std::vector<double> nearly_sorted(std::size_t n, std::size_t swaps = 0,
                                           std::uint64_t seed = 0,
                                           double lo = 1.0, double hi = 1000.0) {
    std::vector<double> v = sorted(n, lo, hi);
    if (n < 2) return v;
    if (swaps == 0) swaps = (n / 20) + 1;
    rng_t r = make_rng(seed);
    std::uniform_int_distribution<std::size_t> pick(0, n - 1);
    for (std::size_t s = 0; s < swaps; ++s) std::swap(v[pick(r)], v[pick(r)]);
    return v;
  }

  // Only `k` distinct values (random assignment) — stresses equal-key handling and
  // makes duplicate runs visible. `k` defaults to a small constant.
  inline std::vector<double> few_unique(std::size_t n, std::size_t k = 5,
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
    return v;
  }

  // Normally distributed values (clamped to [lo, hi]) — a bell-shaped workload.
  inline std::vector<double> gaussian(std::size_t n, std::uint64_t seed = 0,
                                      double lo = 1.0, double hi = 1000.0) {
    std::vector<double> v(n);
    rng_t r = make_rng(seed);
    const double mean = 0.5 * (lo + hi);
    const double stddev = (hi - lo) / 6.0;      // ~99.7% land inside [lo, hi]
    std::normal_distribution<double> d(mean, stddev);
    for (auto& x : v) x = std::clamp(d(r), lo, hi);
    return v;
  }

}  // namespace gen
}  // namespace sa
