#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of merge.ixx (the C++20 module), produced by
// scripts/gen_sa_hpp.py. The .ixx is the source of truth: edit it and re-run
//   py -I scripts/gen_sa_hpp.py
// This header lets the Qt/MinGW app and the tests use the sa core without
// C++20 modules / `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "sa core requires a C++20 compiler (GCC >= 11)."
#endif

// Merge sort — the classic stable divide-and-conquer sort. Recursively split the
// range in half, sort each half, then merge the two sorted runs by repeatedly
// taking the smaller head. Θ(n log n) in all cases (best = average = worst), stable,
// but needs O(n) auxiliary space for the merge buffer. Emits a compare between the
// two run heads and an `overwrite` as each merged value is written back, so a
// visualizer shows the two runs interleaving into place.

#include <vector>

#include "../seq/seq.hpp"
#include "../seq/trace.hpp"

namespace sa {

  namespace detail {
    template <class T, class Compare>
    void merge_runs(std::vector<T>& a, std::vector<T>& buf,
                    std::size_t lo, std::size_t mid, std::size_t hi,
                    Compare& cmp, const tracer& trace) {
      std::size_t i = lo, j = mid, k = lo;
      while (i < mid && j < hi) {
        trace({.kind = evt::compare, .i = i, .j = j, .line = 2});
        if (cmp(a[j], a[i])) buf[k++] = a[j++];   // strict < keeps it stable (ties take left)
        else                 buf[k++] = a[i++];
      }
      while (i < mid) buf[k++] = a[i++];
      while (j < hi)  buf[k++] = a[j++];
      for (std::size_t p = lo; p < hi; ++p) {
        a[p] = buf[p];
        trace({.kind = evt::overwrite, .i = p, .value = value_of(a[p]), .line = 4});
      }
    }

    template <class T, class Compare>
    void merge_sort_rec(std::vector<T>& a, std::vector<T>& buf,
                        std::size_t lo, std::size_t hi, Compare& cmp, const tracer& trace) {
      if (hi - lo <= 1) return;
      const std::size_t mid = lo + (hi - lo) / 2;
      merge_sort_rec(a, buf, lo, mid, cmp, trace);
      merge_sort_rec(a, buf, mid, hi, cmp, trace);
      merge_runs(a, buf, lo, mid, hi, cmp, trace);
    }
  }  // namespace detail

  template <class T, class Compare = less>
  void merge_sort(std::vector<T>& a, Compare cmp = {}, const tracer& trace = ignore) {
    const std::size_t n = a.size();
    if (n < 2) { if (n == 1) trace({.kind = evt::mark_sorted, .i = 0, .line = 0}); return; }
    std::vector<T> buf(n);
    detail::merge_sort_rec(a, buf, 0, n, cmp, trace);
    trace({.kind = evt::mark_sorted, .i = 0, .line = 0});
  }

}  // namespace sa
