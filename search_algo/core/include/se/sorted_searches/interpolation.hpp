#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of interpolation.ixx (the C++20 module), produced by
//   py -I scripts/gen_hpp.py --project search_algo --ns se
// The .ixx is the source of truth: edit it and re-run the generator. This header
// lets the Qt/MinGW app and the tests use the se core without C++20 modules /
// `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "se core requires a C++20 compiler (GCC >= 11)."
#endif

// Interpolation search — for sorted, roughly uniformly distributed NUMERIC keys, guess
// the probe position by linear interpolation between the window ends instead of always
// taking the midpoint (like opening a phone book near where a name should be, not in the
// middle). O(log log n) on uniform data, but degrades toward O(n) on skewed data (e.g.
// gaussian / clustered gaps) — a good contrast to binary search's guaranteed O(log n).
// Uses value_of() for the arithmetic, so it is meant for numeric element types.
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
#include "../seq/seq.hpp"
#include "../seq/trace.hpp"

namespace se {
  template <sorted_searchable R, typename Compare = less>
  index interpolation_search(const R& data, const std::ranges::range_value_t<R>& target,
    Compare cmp = {}, const tracer& trace = ignore) {
    const auto a = std::ranges::begin(data);     // random-access iterator: a[i] is the i-th element
    const std::size_t n = std::ranges::size(data);
    if(n == 0) { trace({.kind = evt::not_found, .line = 7}); return nil; }

    std::size_t lo = 0, hi = n - 1;                     // inclusive window [lo, hi]
    // Keep probing while the target lies within [a[lo], a[hi]].
    while(lo <= hi && !cmp(target, a[lo]) && !cmp(a[hi], target)) {
      std::size_t pos;
      if(lo == hi) {
        pos = lo;
      }
      else {
        const double alo = value_of(a[lo]), ahi = value_of(a[hi]), t = value_of(target);
        const double denom = ahi - alo;
        if(denom == 0.0) {
          pos = lo;
        }
        else {
          double frac = (t - alo) / denom;
          if(frac < 0.0) frac = 0.0;
          if(frac > 1.0) frac = 1.0;
          pos = lo + static_cast<std::size_t>(frac * static_cast<double>(hi - lo));
        }
      }
      trace({.kind = evt::mid, .i = pos, .value = value_of(a[pos]), .line = 3});
      trace({.kind = evt::probe, .i = pos, .value = value_of(a[pos]), .line = 3});
      if(equivalent(a[pos], target, cmp)) {
        trace({.kind = evt::found, .i = pos, .value = value_of(a[pos]), .line = 4});
        return pos;
      }
      if(cmp(a[pos], target)) {                        // a[pos] < target -> go right
        trace({.kind = evt::eliminate, .i = lo, .j = pos, .line = 5});
        lo = pos + 1;
        trace({.kind = evt::lo_bound, .i = lo, .line = 5});
      }
      else {                                          // target < a[pos] -> go left
        if(pos == 0) break;
        trace({.kind = evt::eliminate, .i = pos, .j = hi, .line = 6});
        hi = pos - 1;
        trace({.kind = evt::hi_bound, .i = hi, .line = 6});
      }
    }
    trace({.kind = evt::not_found, .line = 7});
    return nil;
  }
}  // namespace se
