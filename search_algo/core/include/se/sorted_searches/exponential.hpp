#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of exponential.ixx (the C++20 module), produced by
//   py -I scripts/gen_hpp.py --project search_algo --ns se
// The .ixx is the source of truth: edit it and re-run the generator. This header
// lets the Qt/MinGW app and the tests use the se core without C++20 modules /
// `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "se core requires a C++20 compiler (GCC >= 11)."
#endif

// Exponential (a.k.a. galloping / doubling) search — on a sorted array, find a range
// that must contain the target by probing index 1, 2, 4, 8, ... until the value at the
// bound is >= the target, then binary-search the last doubled range [bound/2, bound).
// O(log i) where i is the target's position, so it beats binary search when the target
// is near the front (and it needs no size known up front, which suits unbounded /
// streamed input). Emits the doubling probes, then the embedded binary search's window
// narrowing.

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
  index exponential_search(const R& data, const std::ranges::range_value_t<R>& target,
    Compare cmp = {}, const tracer& trace = ignore) {
    const auto a = std::ranges::begin(data);     // random-access iterator: a[i] is the i-th element
    const std::size_t n = std::ranges::size(data);
    if(n == 0) { trace({.kind = evt::not_found, .line = 6}); return nil; }

    trace({.kind = evt::probe, .i = 0, .value = value_of(a[0]), .line = 1});
    if(equivalent(a[0], target, cmp)) {
      trace({.kind = evt::found, .i = 0, .value = value_of(a[0]), .line = 2});
      return 0;
    }

    std::size_t bound = 1;
    while(bound < n && cmp(a[bound], target)) {        // a[bound] < target -> double the range
      trace({.kind = evt::probe, .i = bound, .value = value_of(a[bound]), .line = 3});
      trace({.kind = evt::eliminate, .i = 0, .j = bound, .line = 3});
      bound *= 2;
    }

    std::size_t lo = bound / 2;
    std::size_t hi = std::min(bound + 1, n);            // binary search in [lo, hi) — bound is inclusive
    trace({.kind = evt::lo_bound, .i = lo, .line = 4});
    if(hi > 0) trace({.kind = evt::hi_bound, .i = hi - 1, .line = 4});
    while(lo < hi) {
      const std::size_t mid = lo + (hi - lo) / 2;
      trace({.kind = evt::mid, .i = mid, .value = value_of(a[mid]), .line = 5});
      trace({.kind = evt::probe, .i = mid, .value = value_of(a[mid]), .line = 5});
      if(cmp(a[mid], target)) {
        trace({.kind = evt::eliminate, .i = lo, .j = mid, .line = 5});
        lo = mid + 1;
        trace({.kind = evt::lo_bound, .i = lo, .line = 5});
      }
      else if(cmp(target, a[mid])) {
        trace({.kind = evt::eliminate, .i = mid, .j = hi - 1, .line = 5});
        hi = mid;
        if(hi > 0) trace({.kind = evt::hi_bound, .i = hi - 1, .line = 5});
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
