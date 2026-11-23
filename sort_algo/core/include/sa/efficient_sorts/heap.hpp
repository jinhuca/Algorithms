#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of heap.ixx (the C++20 module), produced by
// scripts/gen_sa_hpp.py. The .ixx is the source of truth: edit it and re-run
//   py -I scripts/gen_sa_hpp.py
// This header lets the Qt/MinGW app and the tests use the sa core without
// C++20 modules / `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "sa core requires a C++20 compiler (GCC >= 11)."
#endif

// Heap sort — build a binary max-heap in the array, then repeatedly swap the root
// (the maximum) to the end and sift the new root down to restore the heap, growing a
// sorted suffix. Θ(n log n) in all cases, in-place (O(1) extra), not stable. Emits
// compares + swaps during each sift-down and marks each element settled as it lands
// at the end — so a visualizer shows the heap draining into the sorted tail.

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
  namespace detail {
    // Restore the max-heap property at `root` within the heap a[0..n). Uses the
    // comparator as "<", so the largest element bubbles to the top.
    template <typename It, typename Compare>
    void sift_down(It a, std::size_t root, std::size_t n,
      Compare& cmp, const tracer& trace, int line) {
      for(;;) {
        std::size_t largest = root;
        const std::size_t l = 2 * root + 1, r = 2 * root + 2;
        if(l < n) { trace({.kind = evt::compare, .i = largest, .j = l, .line = line}); if(cmp(a[largest], a[l])) largest = l; }
        if(r < n) { trace({.kind = evt::compare, .i = largest, .j = r, .line = line}); if(cmp(a[largest], a[r])) largest = r; }
        if(largest == root) break;
        std::swap(a[root], a[largest]);
        trace({.kind = evt::swap, .i = root, .j = largest, .line = line});
        root = largest;
      }
    }
  }  // namespace detail

  template <sortable R, typename Compare = less>
  void heap_sort(R& data, Compare cmp = {}, const tracer& trace = ignore) {
    auto a = std::ranges::begin(data);           // mutable random-access iterator: a[i] is element i
    const std::size_t n = std::ranges::size(data);
    if(n < 2) { if(n == 1) trace({.kind = evt::mark_sorted, .i = 0, .line = 3}); return; }

    for(std::size_t i = n / 2; i-- > 0;)             // build the heap bottom-up
      detail::sift_down(a, i, n, cmp, trace, /*line=*/0);

    for(std::size_t end = n; --end > 0;) {           // repeatedly extract the max
      std::swap(a[0], a[end]);
      trace({.kind = evt::swap, .i = 0, .j = end, .line = 2});
      trace({.kind = evt::mark_sorted, .i = end, .line = 3});
      detail::sift_down(a, 0, end, cmp, trace, /*line=*/4);
    }
    trace({.kind = evt::mark_sorted, .i = 0, .line = 3});
  }
}  // namespace sa
