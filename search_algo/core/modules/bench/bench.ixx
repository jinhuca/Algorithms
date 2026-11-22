module;

// se::bench — a tiny timing harness + op-counters for benchmarking searches, the
// search-studio analogue of sa::bench.
//
// time_it() runs a callable `warmup` times (untimed) then `runs` times (timed) and
// returns min / median / mean / stddev in milliseconds. do_not_optimize() keeps the
// compiler from eliding a result that is otherwise unused — crucial here, since a
// search that merely returns an index is trivially dead-code-eliminated otherwise.
//
// IMPORTANT: a timed run must call the search WITHOUT a tracer (the default se::ignore)
// — recording steps would dominate the measurement. The counting tracer here is for a
// SEPARATE, untimed run only, to tally probes / window updates.

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstddef>
#include <vector>

export module se.bench;

import se.trace;

export namespace se {
namespace bench {

  // Keep `value` observably "used" so the optimizer can't delete the work that
  // produced it (Google-Benchmark's trick). Call it on each iteration's result.
  template <class T>
  inline void do_not_optimize(const T& value) {
#if defined(__clang__) || defined(__GNUC__)
    asm volatile("" : : "m"(value) : "memory");
#else
    const volatile char sink = *reinterpret_cast<const volatile char*>(&value);
    (void)sink;
#endif
  }

  struct result {
    std::size_t runs = 0;
    double min_ms = 0;
    double median_ms = 0;
    double mean_ms = 0;
    double stddev_ms = 0;
  };

  // Time `fn` over `runs` timed iterations after `warmup` untimed ones.
  template <class Fn>
  result time_it(Fn&& fn, int runs = 5, int warmup = 1) {
    for (int i = 0; i < warmup; ++i) fn();
    std::vector<double> ms;
    ms.reserve(runs > 0 ? static_cast<std::size_t>(runs) : 0);
    for (int i = 0; i < runs; ++i) {
      const auto t0 = std::chrono::steady_clock::now();
      fn();
      const auto t1 = std::chrono::steady_clock::now();
      ms.push_back(std::chrono::duration<double, std::milli>(t1 - t0).count());
    }
    result out;
    out.runs = ms.size();
    if (ms.empty()) return out;
    std::vector<double> srt = ms;
    std::sort(srt.begin(), srt.end());
    const std::size_t n = srt.size();
    out.min_ms = srt.front();
    out.median_ms = (n % 2) ? srt[n / 2] : 0.5 * (srt[n / 2 - 1] + srt[n / 2]);
    double sum = 0;
    for (double x : ms) sum += x;
    out.mean_ms = sum / static_cast<double>(n);
    double acc = 0;
    for (double x : ms) { const double d = x - out.mean_ms; acc += d * d; }
    out.stddev_ms = std::sqrt(acc / static_cast<double>(n));
    return out;
  }

  // Per-event operation counts, filled by count_into()'s tracer on an untimed run.
  // `probes` (each probe is one element examined / compared against the target) is the
  // classic search cost metric shown in the Analyzer table.
  struct counters {
    std::size_t probe = 0;
    std::size_t lo_bound = 0;
    std::size_t hi_bound = 0;
    std::size_t mid = 0;
    std::size_t eliminate = 0;
    std::size_t found = 0;
    std::size_t not_found = 0;
    std::size_t pass_boundary = 0;
    std::size_t message = 0;
    std::size_t total = 0;
    // The headline cost: how many elements the search examined.
    std::size_t probes() const { return probe; }
  };

  // A tracer that tallies each step kind into `c`. Pass it to a search's trace
  // parameter for a SEPARATE, untimed counted run.
  inline tracer count_into(counters& c) {
    return [&c](const step& s) {
      ++c.total;
      switch (s.kind) {
        case evt::probe:         ++c.probe;         break;
        case evt::lo_bound:      ++c.lo_bound;      break;
        case evt::hi_bound:      ++c.hi_bound;      break;
        case evt::mid:           ++c.mid;           break;
        case evt::eliminate:     ++c.eliminate;     break;
        case evt::found:         ++c.found;         break;
        case evt::not_found:     ++c.not_found;     break;
        case evt::pass_boundary: ++c.pass_boundary; break;
        case evt::message:       ++c.message;       break;
      }
    };
  }

}  // namespace bench
}  // namespace se
