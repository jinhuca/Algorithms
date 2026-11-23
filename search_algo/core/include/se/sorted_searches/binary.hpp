#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of binary.ixx (the C++20 module), produced by
// scripts/gen_se_hpp.py. The .ixx is the source of truth: edit it and re-run
//   py -I scripts/gen_se_hpp.py
// This header lets the Qt/MinGW app and the tests use the se core without
// C++20 modules / `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "se core requires a C++20 compiler (GCC >= 11)."
#endif

// Binary search — the archetypal sorted-array search. Keep a half-open window
// [lo, hi); probe the midpoint and discard the half that cannot contain the target.
// Requires the array sorted by the same comparator. O(log n) comparisons, O(1) space.
// Emits lo_bound / hi_bound as the window narrows, a mid + probe at each midpoint, and
// an eliminate for the discarded half, so a visualizer shows the window collapsing.

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
  index binary_search(const R& data, const std::ranges::range_value_t<R>& target,
    Compare cmp = {}, const tracer& trace = ignore) {
    const auto a = std::ranges::begin(data);     // random-access iterator: a[i] is the i-th element
    std::size_t lo = 0, hi = std::ranges::size(data);   // window is [lo, hi)
    while(lo < hi) {
      const std::size_t mid = lo + (hi - lo) / 2;
      trace({.kind = evt::mid, .i = mid, .value = value_of(a[mid]), .line = 2});
      trace({.kind = evt::probe, .i = mid, .value = value_of(a[mid]), .line = 2});
      if(cmp(a[mid], target)) {                 // a[mid] < target -> answer is to the right
        trace({.kind = evt::eliminate, .i = lo, .j = mid, .line = 3});
        lo = mid + 1;
        trace({.kind = evt::lo_bound, .i = lo, .line = 3});
      }
      else if(cmp(target, a[mid])) {          // target < a[mid] -> answer is to the left
        trace({.kind = evt::eliminate, .i = mid, .j = hi - 1, .line = 4});
        hi = mid;
        if(hi > 0) trace({.kind = evt::hi_bound, .i = hi - 1, .line = 4});
      }
      else {
        trace({.kind = evt::found, .i = mid, .value = value_of(a[mid]), .line = 5});
        return mid;
      }
    }
    trace({.kind = evt::not_found, .line = 6});
    return nil;
  }
}  // namespace se
