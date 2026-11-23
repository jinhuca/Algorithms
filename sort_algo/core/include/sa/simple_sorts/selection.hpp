#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of selection.ixx (the C++20 module), produced by
// scripts/gen_sa_hpp.py. The .ixx is the source of truth: edit it and re-run
//   py -I scripts/gen_sa_hpp.py
// This header lets the Qt/MinGW app and the tests use the sa core without
// C++20 modules / `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "sa core requires a C++20 compiler (GCC >= 11)."
#endif

// Selection sort — grow a sorted prefix: each pass scans the unsorted tail for its
// minimum and swaps it into the next prefix slot. In-place, not stable, always
// Θ(n²) comparisons but at most n-1 swaps (cheap when writes are expensive). Emits a
// `cursor` at the fill slot, compares across the tail, one swap per pass, and marks
// each prefix position settled.

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
  template <sortable R, typename Compare = less>
  void selection_sort(R& data, Compare cmp = {}, const tracer& trace = ignore) {
    auto a = std::ranges::begin(data);           // mutable random-access iterator: a[i] is element i
    const std::size_t n = std::ranges::size(data);
    for(std::size_t i = 0; i + 1 < n; ++i) {
      trace({.kind = evt::cursor, .i = i, .value = value_of(a[i]), .line = 1});
      std::size_t m = i;                          // index of the smallest seen
      for(std::size_t j = i + 1; j < n; ++j) {
        trace({.kind = evt::compare, .i = m, .j = j, .line = 3});
        if(cmp(a[j], a[m])) m = j;
      }
      if(m != i) {
        std::swap(a[i], a[m]);
        trace({.kind = evt::swap, .i = i, .j = m, .line = 4});
      }
      trace({.kind = evt::mark_sorted, .i = i, .line = 5});
    }
    if(n > 0) trace({.kind = evt::mark_sorted, .i = n - 1, .line = 5});
  }
}  // namespace sa
