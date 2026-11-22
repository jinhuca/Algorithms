#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of bubble.ixx (the C++20 module), produced by
// scripts/gen_sa_hpp.py. The .ixx is the source of truth: edit it and re-run
//   py -I scripts/gen_sa_hpp.py
// This header lets the Qt/MinGW app and the tests use the sa core without
// C++20 modules / `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "sa core requires a C++20 compiler (GCC >= 11)."
#endif

// Bubble sort — repeatedly walk the array swapping adjacent out-of-order pairs, so
// the largest remaining element "bubbles" to the end of each pass. Stable, in-place,
// O(n²) comparisons; O(n) best case on already-sorted input thanks to the early-exit
// when a pass makes no swaps. Emits compare / swap steps and marks each settled tail
// position, so a visualizer can animate the classic bubbling.

#include <utility>
#include <vector>

#include "../seq/seq.hpp"
#include "../seq/trace.hpp"

namespace sa {

  template <class T, class Compare = less>
  void bubble_sort(std::vector<T>& a, Compare cmp = {}, const tracer& trace = ignore) {
    const std::size_t n = a.size();
    for (std::size_t end = n; end > 1; --end) {
      bool swapped = false;
      for (std::size_t i = 0; i + 1 < end; ++i) {
        trace({.kind = evt::compare, .i = i, .j = i + 1, .line = 2});
        if (cmp(a[i + 1], a[i])) {
          std::swap(a[i], a[i + 1]);
          trace({.kind = evt::swap, .i = i, .j = i + 1, .line = 3});
          swapped = true;
        }
      }
      trace({.kind = evt::mark_sorted, .i = end - 1, .line = 4});
      trace({.kind = evt::pass_boundary, .note = "pass complete", .line = 0});
      if (!swapped) break;        // no swaps -> the whole array is already ordered
    }
    if (n > 0) trace({.kind = evt::mark_sorted, .i = 0, .line = 4});
  }

}  // namespace sa
