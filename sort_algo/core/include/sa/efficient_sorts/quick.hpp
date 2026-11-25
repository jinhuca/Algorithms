#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of quick.ixx (the C++20 module), produced by
//   py -I scripts/gen_hpp.py --project sort_algo --ns sa
// The .ixx is the source of truth: edit it and re-run the generator. This header
// lets the Qt/MinGW app and the tests use the sa core without C++20 modules /
// `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "sa core requires a C++20 compiler (GCC >= 11)."
#endif

// Quick sort — the in-place divide-and-conquer workhorse. Partition the range about
// a pivot (here Lomuto's scheme with the last element as pivot) so smaller elements
// go left and larger go right, leaving the pivot in its final slot, then recurse on
// each side. O(n log n) on average with small constants, but O(n²) in the worst case
// (e.g. already-sorted input with this pivot choice); in-place, not stable. Emits the
// pivot as a `cursor`, a compare per scanned element, swaps as elements are moved,
// and marks each pivot settled — so a visualizer shows the partition forming.

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
    template <typename It, typename Compare>
    std::size_t partition_lomuto(It a, std::size_t lo, std::size_t hi,
      Compare& cmp, const tracer& trace) {
      trace({.kind = evt::cursor, .i = hi, .value = value_of(a[hi]), .line = 0});   // pivot = a[hi]
      std::size_t i = lo;
      for(std::size_t j = lo; j < hi; ++j) {
        trace({.kind = evt::compare, .i = j, .j = hi, .line = 1});
        if(cmp(a[j], a[hi])) {
          if(i != j) { std::swap(a[i], a[j]); trace({.kind = evt::swap, .i = i, .j = j, .line = 2}); }
          ++i;
        }
      }
      if(i != hi) { std::swap(a[i], a[hi]); trace({.kind = evt::swap, .i = i, .j = hi, .line = 3}); }
      trace({.kind = evt::mark_sorted, .i = i, .line = 3});   // pivot now in its final place
      return i;
    }

    // Iterative to avoid deep recursion on adversarial (worst-case) input.
    template <typename It, typename Compare>
    void quick_sort_impl(It a, std::size_t n, Compare& cmp, const tracer& trace) {
      if(n < 2) return;
      std::vector<std::pair<std::size_t, std::size_t>> stack;
      stack.push_back({0, n - 1});
      while(!stack.empty()) {
        auto [lo, hi] = stack.back();
        stack.pop_back();
        if(lo >= hi) continue;
        const std::size_t p = partition_lomuto(a, lo, hi, cmp, trace);
        if(p > lo) stack.push_back({lo, p - 1});       // left side (p-1 safe: p > lo >= 0)
        if(p < hi) stack.push_back({p + 1, hi});       // right side (p+1 safe: p < hi)
      }
    }
  }  // namespace detail

  template <typename R, typename Compare = less>
    requires sortable<R, Compare>
  void quick_sort(R& data, Compare cmp = {}, const tracer& trace = ignore) {
    auto a = std::ranges::begin(data);           // mutable random-access iterator: a[i] is element i
    const std::size_t n = std::ranges::size(data);
    detail::quick_sort_impl(a, n, cmp, trace);
    if(n > 0) trace({.kind = evt::mark_sorted, .i = 0, .line = 4});
  }
}  // namespace sa
