#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of cocktail.ixx (the C++20 module), produced by
// scripts/gen_sa_hpp.py. The .ixx is the source of truth: edit it and re-run
//   py -I scripts/gen_sa_hpp.py
// This header lets the Qt/MinGW app and the tests use the sa core without
// C++20 modules / `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "sa core requires a C++20 compiler (GCC >= 11)."
#endif

// Cocktail shaker sort — bidirectional bubble sort. Each round bubbles the largest
// remaining element up to the right end, then the smallest down to the left end, so
// the sorted region grows from both sides and small values near the end ("turtles")
// reach home far faster than in plain bubble sort. Stable, in-place, O(n²), with the
// same no-swap early exit. Emits compares, swaps, and marks both settling ends.

#include <utility>
#include <vector>

#include "../seq/seq.hpp"
#include "../seq/trace.hpp"

namespace sa {

  template <class T, class Compare = less>
  void cocktail_sort(std::vector<T>& a, Compare cmp = {}, const tracer& trace = ignore) {
    const std::size_t n = a.size();
    if (n < 2) {
      if (n == 1) trace({.kind = evt::mark_sorted, .i = 0, .line = 0});
      return;
    }
    std::size_t lo = 0, hi = n - 1;
    bool swapped = true;
    while (swapped && lo < hi) {
      swapped = false;
      for (std::size_t i = lo; i < hi; ++i) {               // forward: bubble max up
        trace({.kind = evt::compare, .i = i, .j = i + 1, .line = 2});
        if (cmp(a[i + 1], a[i])) {
          std::swap(a[i], a[i + 1]);
          trace({.kind = evt::swap, .i = i, .j = i + 1, .line = 2});
          swapped = true;
        }
      }
      trace({.kind = evt::mark_sorted, .i = hi, .line = 1});
      --hi;
      trace({.kind = evt::pass_boundary, .note = "forward pass", .line = 1});
      if (!swapped) break;

      swapped = false;
      for (std::size_t i = hi; i > lo; --i) {               // backward: bubble min down
        trace({.kind = evt::compare, .i = i - 1, .j = i, .line = 4});
        if (cmp(a[i], a[i - 1])) {
          std::swap(a[i - 1], a[i]);
          trace({.kind = evt::swap, .i = i - 1, .j = i, .line = 4});
          swapped = true;
        }
      }
      trace({.kind = evt::mark_sorted, .i = lo, .line = 3});
      ++lo;
      trace({.kind = evt::pass_boundary, .note = "backward pass", .line = 3});
    }
    for (std::size_t k = lo; k <= hi && hi < n; ++k) trace({.kind = evt::mark_sorted, .i = k, .line = 0});
  }

}  // namespace sa
