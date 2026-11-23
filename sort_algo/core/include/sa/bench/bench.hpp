#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of bench.ixx (the C++20 module), produced by
// scripts/gen_sa_hpp.py. The .ixx is the source of truth: edit it and re-run
//   py -I scripts/gen_sa_hpp.py
// This header lets the Qt/MinGW app and the tests use the sa core without
// C++20 modules / `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "sa core requires a C++20 compiler (GCC >= 11)."
#endif

// sa::bench — a tiny timing harness + op-counters for benchmarking sorts, the
// sort-algo analogue of ga::bench.
//
// time_it() runs a callable `warmup` times (untimed) then `runs` times (timed) and
// returns min / median / mean / stddev in milliseconds. do_not_optimize() keeps the
// compiler from eliding a result that is otherwise unused.
//
// IMPORTANT: a timed run must call the sort WITHOUT a tracer (the default
// sa::ignore) — recording steps would dominate the measurement. The counting tracer
// here is for a SEPARATE, untimed run only, to tally comparisons / swaps / writes.

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
#include "../seq/trace.hpp"

namespace sa {
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

    // ---- peak heap tracking (opt-in) -----------------------------------------
    // Measures the peak extra bytes a single algorithm run allocates (merge/radix
    // use O(n) scratch; the in-place sorts ~0). The counters are thread-local and
    // updated by a global operator new/delete override that an executable opts into
    // by linking a tracker TU (see studio/mem_tracker.cpp); without it these stay
    // zero. Thread-local so the measuring worker thread isn't polluted by others and
    // the override costs ~nothing when not active.
    namespace mem {
      inline thread_local std::size_t current = 0;
      inline thread_local std::size_t peak = 0;
      inline thread_local bool tracking = false;

      inline void on_alloc(std::size_t n) {
        current += n;
        if(current > peak) peak = current;
      }
      inline void on_free(std::size_t n) {
        current = (current >= n) ? current - n : 0;   // guard a pre-window free
      }
      inline void start() { current = 0; peak = 0; tracking = true; }   // begin a measured region
      inline void stop() { tracking = false; }
      inline std::size_t peak_bytes() { return peak; }
    }  // namespace mem

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
      for(int i = 0; i < warmup; ++i) fn();
      std::vector<double> ms;
      ms.reserve(runs > 0 ? static_cast<std::size_t>(runs) : 0);
      for(int i = 0; i < runs; ++i) {
        const auto t0 = std::chrono::steady_clock::now();
        fn();
        const auto t1 = std::chrono::steady_clock::now();
        ms.push_back(std::chrono::duration<double, std::milli>(t1 - t0).count());
      }
      result out;
      out.runs = ms.size();
      if(ms.empty()) return out;
      std::vector<double> srt = ms;
      std::sort(srt.begin(), srt.end());
      const std::size_t n = srt.size();
      out.min_ms = srt.front();
      out.median_ms = (n % 2) ? srt[n / 2] : 0.5 * (srt[n / 2 - 1] + srt[n / 2]);
      double sum = 0;
      for(double x : ms) sum += x;
      out.mean_ms = sum / static_cast<double>(n);
      double acc = 0;
      for(double x : ms) { const double d = x - out.mean_ms; acc += d * d; }
      out.stddev_ms = std::sqrt(acc / static_cast<double>(n));
      return out;
    }

    // Per-event operation counts, filled by count_into()'s tracer on an untimed run.
    // `comparisons` and `writes` (swap counts as two writes) are the classic sort
    // cost metrics shown in the Analyzer table.
    struct counters {
      std::size_t compare = 0;
      std::size_t swap = 0;
      std::size_t overwrite = 0;
      std::size_t read = 0;
      std::size_t cursor = 0;
      std::size_t mark_sorted = 0;
      std::size_t pass_boundary = 0;
      std::size_t message = 0;
      std::size_t total = 0;
      // Writes = each swap moves two elements + each overwrite is one element written.
      std::size_t writes() const { return swap * 2 + overwrite; }
    };

    // A tracer that tallies each step kind into `c`. Pass it to a sort's trace
    // parameter for a SEPARATE, untimed counted run.
    inline tracer count_into(counters& c) {
      return [&c](const step& s) {
        ++c.total;
        switch(s.kind) {
        case evt::compare:       ++c.compare;       break;
        case evt::swap:          ++c.swap;          break;
        case evt::overwrite:     ++c.overwrite;     break;
        case evt::read:          ++c.read;          break;
        case evt::cursor:        ++c.cursor;        break;
        case evt::mark_sorted:   ++c.mark_sorted;   break;
        case evt::pass_boundary: ++c.pass_boundary; break;
        case evt::message:       ++c.message;       break;
        }
      };
    }
  }  // namespace bench
}  // namespace sa
