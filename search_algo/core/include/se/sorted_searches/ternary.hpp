#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of ternary.ixx (the C++20 module), produced by
// scripts/gen_se_hpp.py. The .ixx is the source of truth: edit it and re-run
//   py -I scripts/gen_se_hpp.py
// This header lets the Qt/MinGW app and the tests use the se core without
// C++20 modules / `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "se core requires a C++20 compiler (GCC >= 11)."
#endif

// Ternary search — like binary search, but each iteration uses TWO probes (m1 < m2) to
// split the sorted window into three parts, then keeps the one third that can contain
// the target. Requires sorted data. Fewer iterations than binary (log base 3) but up to
// two comparisons per iteration, so in practice it does MORE comparisons than binary —
// a nice teaching contrast. O(log n) overall, O(1) space. Emits both probes and the
// eliminated region(s) each step.

#include <vector>

#include "../seq/seq.hpp"
#include "../seq/trace.hpp"

namespace se {

  template <class T, class Compare = less>
  index ternary_search(const std::vector<T>& a, const T& target,
                       Compare cmp = {}, const tracer& trace = ignore) {
    std::size_t lo = 0, hi = a.size();           // window [lo, hi)
    while (hi - lo > 2) {
      const std::size_t len = hi - lo;
      std::size_t m1 = lo + len / 3;
      std::size_t m2 = hi - 1 - len / 3;
      if (m2 <= m1) m2 = m1 + 1;                 // keep the two probes distinct
      if (m2 >= hi) m2 = hi - 1;

      trace({.kind = evt::mid, .i = m1, .value = value_of(a[m1]), .line = 2});
      trace({.kind = evt::probe, .i = m1, .value = value_of(a[m1]), .line = 2});
      if (equivalent(a[m1], target, cmp)) {
        trace({.kind = evt::found, .i = m1, .value = value_of(a[m1]), .line = 3});
        return m1;
      }
      trace({.kind = evt::mid, .i = m2, .value = value_of(a[m2]), .line = 4});
      trace({.kind = evt::probe, .i = m2, .value = value_of(a[m2]), .line = 4});
      if (equivalent(a[m2], target, cmp)) {
        trace({.kind = evt::found, .i = m2, .value = value_of(a[m2]), .line = 5});
        return m2;
      }

      if (cmp(target, a[m1])) {                  // target < a[m1] -> left third
        trace({.kind = evt::eliminate, .i = m1, .j = hi - 1, .line = 6});
        hi = m1;
        if (hi > 0) trace({.kind = evt::hi_bound, .i = hi - 1, .line = 6});
      } else if (cmp(a[m2], target)) {           // a[m2] < target -> right third
        trace({.kind = evt::eliminate, .i = lo, .j = m2, .line = 7});
        lo = m2 + 1;
        trace({.kind = evt::lo_bound, .i = lo, .line = 7});
      } else {                                   // middle third
        trace({.kind = evt::eliminate, .i = lo, .j = m1, .line = 8});
        trace({.kind = evt::eliminate, .i = m2, .j = hi - 1, .line = 8});
        lo = m1 + 1; hi = m2;
        trace({.kind = evt::lo_bound, .i = lo, .line = 8});
        if (hi > 0) trace({.kind = evt::hi_bound, .i = hi - 1, .line = 8});
      }
    }
    // small window [lo, hi): 0..2 elements remain — check them directly.
    for (std::size_t i = lo; i < hi; ++i) {
      trace({.kind = evt::probe, .i = i, .value = value_of(a[i]), .line = 9});
      if (equivalent(a[i], target, cmp)) {
        trace({.kind = evt::found, .i = i, .value = value_of(a[i]), .line = 10});
        return i;
      }
    }
    trace({.kind = evt::not_found, .line = 11});
    return nil;
  }

}  // namespace se
