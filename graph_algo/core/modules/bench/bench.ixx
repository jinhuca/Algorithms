module;

// ga::bench — a tiny timing harness + op-counters for benchmarking algorithms.
//
// time_it() runs a callable `warmup` times (untimed) then `runs` times (timed)
// and returns min / median / mean / stddev in milliseconds. do_not_optimize()
// keeps the compiler from eliding a result that is otherwise unused.
//
// IMPORTANT: a timed run must call the algorithm WITHOUT a tracer (the default
// ga::ignore) — recording steps would dominate the measurement. The counting
// tracer here is for a SEPARATE, untimed run only.
export module ga.bench;
import std;

import ga.trace;

export namespace ga {
namespace bench {

  // Keep `value` observably "used" so the optimizer can't delete the work that
  // produced it (Google-Benchmark's trick). Call it on each iteration's result.
  template <typename T>
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
  template <typename Fn>
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
    std::vector<double> sorted = ms;
    std::sort(sorted.begin(), sorted.end());
    const std::size_t n = sorted.size();
    out.min_ms = sorted.front();
    out.median_ms = (n % 2) ? sorted[n / 2]
                            : 0.5 * (sorted[n / 2 - 1] + sorted[n / 2]);
    double sum = 0;
    for (double x : ms) sum += x;
    out.mean_ms = sum / static_cast<double>(n);
    double acc = 0;
    for (double x : ms) { const double d = x - out.mean_ms; acc += d * d; }
    out.stddev_ms = std::sqrt(acc / static_cast<double>(n));
    return out;
  }

  // Per-event operation counts, filled by count_into()'s tracer on an untimed run.
  struct counters {
    std::size_t discover_vertex = 0;
    std::size_t visit_vertex = 0;
    std::size_t finish_vertex = 0;
    std::size_t examine_edge = 0;
    std::size_t tree_edge = 0;
    std::size_t relax_edge = 0;
    std::size_t skip_edge = 0;
    std::size_t found_target = 0;
    std::size_t message = 0;
    std::size_t total = 0;
  };

  // ---- peak heap tracking (opt-in) -----------------------------------------
  // Measures the peak extra bytes a single algorithm run allocates. The counters
  // are thread-local and updated by a global operator new/delete override that an
  // executable opts into by linking a tracker TU (see visualizer/mem_tracker.cpp);
  // without it these stay zero. Thread-local so the measuring worker thread isn't
  // polluted by other threads, and so the override costs ~nothing when not active.
  namespace mem {
    inline thread_local std::size_t current = 0;
    inline thread_local std::size_t peak = 0;
    inline thread_local bool tracking = false;

    inline void on_alloc(std::size_t n) {
      current += n;
      if (current > peak) peak = current;
    }
    inline void on_free(std::size_t n) {
      current = (current >= n) ? current - n : 0;   // guard a pre-window free
    }
    inline void start() { current = 0; peak = 0; tracking = true; }   // begin a measured region
    inline void stop() { tracking = false; }
    inline std::size_t peak_bytes() { return peak; }
  }  // namespace mem

  // A tracer that tallies each step kind into `c`. Pass it to an algorithm's
  // trace parameter for a SEPARATE, untimed counted run.
  inline tracer count_into(counters& c) {
    return [&c](const step& s) {
      ++c.total;
      switch (s.kind) {
        case evt::discover_vertex: ++c.discover_vertex; break;
        case evt::visit_vertex:    ++c.visit_vertex;    break;
        case evt::finish_vertex:   ++c.finish_vertex;   break;
        case evt::examine_edge:    ++c.examine_edge;    break;
        case evt::tree_edge:       ++c.tree_edge;       break;
        case evt::relax_edge:      ++c.relax_edge;      break;
        case evt::skip_edge:       ++c.skip_edge;       break;
        case evt::found_target:    ++c.found_target;    break;
        case evt::message:         ++c.message;         break;
      }
    };
  }

}  // namespace bench
}  // namespace ga
