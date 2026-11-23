#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of fibonacci.ixx (the C++20 module), produced by
// scripts/gen_se_hpp.py. The .ixx is the source of truth: edit it and re-run
//   py -I scripts/gen_se_hpp.py
// This header lets the Qt/MinGW app and the tests use the se core without
// C++20 modules / `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "se core requires a C++20 compiler (GCC >= 11)."
#endif

// Fibonacci search — bisect a sorted array using Fibonacci numbers instead of halving,
// so each probe splits the window in the golden ratio and every probe index is reached
// by only addition/subtraction (no division) — historically useful on hardware without
// a fast divide, and it favours smaller forward jumps. O(log n) comparisons, O(1)
// space, same asymptotics as binary search. Emits a probe per Fibonacci step and the
// region eliminated each time.

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
#include "../seq/seq.hpp"
#include "../seq/trace.hpp"

namespace se {
  template <sorted_searchable R, typename Compare = less>
  index fibonacci_search(const R& data, const std::ranges::range_value_t<R>& target,
    Compare cmp = {}, const tracer& trace = ignore) {
    const auto a = std::ranges::begin(data);     // random-access iterator: a[i] is the i-th element
    const std::size_t n = std::ranges::size(data);
    if(n == 0) { trace({.kind = evt::not_found, .line = 8}); return nil; }

    std::size_t f2 = 0, f1 = 1, f = f2 + f1;            // consecutive Fibonaccis: f = f2 + f1
    while(f < n) { f2 = f1; f1 = f; f = f2 + f1; }

    long long offset = -1;                               // highest index already eliminated at the front
    while(f > 1) {
      const long long cand = offset + static_cast<long long>(f2);
      const std::size_t i =
        static_cast<std::size_t>(std::min<long long>(cand, static_cast<long long>(n) - 1));
      trace({.kind = evt::probe, .i = i, .value = value_of(a[i]), .line = 3});
      if(cmp(a[i], target)) {                           // a[i] < target -> move the window up
        f = f1; f1 = f2; f2 = f - f1;
        trace({.kind = evt::eliminate, .i = 0, .j = i, .line = 4});
        offset = static_cast<long long>(i);
      }
      else if(cmp(target, a[i])) {                    // target < a[i] -> cut the rear
        f = f2; f1 = f1 - f2; f2 = f - f1;
        if(i < n) trace({.kind = evt::eliminate, .i = i, .j = n - 1, .line = 5});
      }
      else {
        trace({.kind = evt::found, .i = i, .value = value_of(a[i]), .line = 6});
        return i;
      }
    }
    // one element may remain just past the eliminated front.
    if(f1 && offset + 1 < static_cast<long long>(n)) {
      const std::size_t i = static_cast<std::size_t>(offset + 1);
      trace({.kind = evt::probe, .i = i, .value = value_of(a[i]), .line = 7});
      if(equivalent(a[i], target, cmp)) {
        trace({.kind = evt::found, .i = i, .value = value_of(a[i]), .line = 6});
        return i;
      }
    }
    trace({.kind = evt::not_found, .line = 8});
    return nil;
  }
}  // namespace se
