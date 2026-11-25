#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of shell.ixx (the C++20 module), produced by
//   py -I scripts/gen_hpp.py --project sort_algo --ns sa
// The .ixx is the source of truth: edit it and re-run the generator. This header
// lets the Qt/MinGW app and the tests use the sa core without C++20 modules /
// `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "sa core requires a C++20 compiler (GCC >= 11)."
#endif

// Shell sort — insertion sort generalised to compare-and-shift elements a "gap"
// apart, with the gap shrinking to 1 on the final pass (a plain insertion sort by
// then, but on an almost-sorted array). Early large gaps move elements a long way
// cheaply, breaking up the "turtles" that make insertion sort slow, so it runs in
// roughly O(n log²n) with the Knuth gap sequence (1, 4, 13, 40, …) used here. In-
// place, not stable. Emits the held key as a `cursor`, a compare per gapped
// neighbour, and `overwrite` steps for each shift — so the visualizer shows the
// gapped passes tightening.

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

namespace sa {
  template <typename R, typename Compare = less>
    requires sortable<R, Compare>
  void shell_sort(R& data, Compare cmp = {}, const tracer& trace = ignore) {
    using T = std::ranges::range_value_t<R>;
    auto a = std::ranges::begin(data);           // mutable random-access iterator: a[i] is element i
    const std::size_t n = std::ranges::size(data);
    if(n < 2) { if(n == 1) trace({.kind = evt::mark_sorted, .i = 0, .line = 0}); return; }

    std::size_t gap = 1;                       // largest Knuth gap < n/3
    while(gap < n / 3) gap = gap * 3 + 1;

    for(; gap >= 1; gap /= 3) {
      for(std::size_t i = gap; i < n; ++i) {
        T key = a[i];
        const double kv = value_of(key);
        trace({.kind = evt::cursor, .i = i, .value = kv, .line = 2});
        std::size_t j = i;
        while(j >= gap) {
          trace({.kind = evt::compare, .i = j - gap, .j = i, .line = 3});
          if(cmp(key, a[j - gap])) {
            a[j] = a[j - gap];
            trace({.kind = evt::overwrite, .i = j, .value = value_of(a[j]), .line = 4});
            j -= gap;
          }
          else {
            break;
          }
        }
        a[j] = key;
        trace({.kind = evt::overwrite, .i = j, .value = kv, .line = 5});
      }
      trace({.kind = evt::pass_boundary, .value = static_cast<double>(gap), .note = "gap pass", .line = 0});
      if(gap == 1) break;                     // avoid unsigned 1/3 == 0 underflow loop
    }
    trace({.kind = evt::mark_sorted, .i = 0, .line = 0});
  }
}  // namespace sa
