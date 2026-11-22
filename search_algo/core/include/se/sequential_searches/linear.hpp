#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of linear.ixx (the C++20 module), produced by
// scripts/gen_se_hpp.py. The .ixx is the source of truth: edit it and re-run
//   py -I scripts/gen_se_hpp.py
// This header lets the Qt/MinGW app and the tests use the se core without
// C++20 modules / `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "se core requires a C++20 compiler (GCC >= 11)."
#endif

// Linear (sequential) search — walk the array front to back, comparing each element
// against the target, and return the first match. The only search that needs NO
// ordering: it works on unsorted data. O(n) comparisons worst / average, O(1) best
// (a match at the front). Emits a `probe` per element and a `found` / `not_found`, so
// a visualizer sweeps a cursor along the array.

#include <vector>

#include "../seq/seq.hpp"
#include "../seq/trace.hpp"

namespace se {

  template <class T, class Compare = less>
  index linear_search(const std::vector<T>& a, const T& target,
                      Compare cmp = {}, const tracer& trace = ignore) {
    const std::size_t n = a.size();
    for (std::size_t i = 0; i < n; ++i) {
      trace({.kind = evt::probe, .i = i, .value = value_of(a[i]), .line = 1});
      if (equivalent(a[i], target, cmp)) {
        trace({.kind = evt::found, .i = i, .value = value_of(a[i]), .line = 2});
        return i;
      }
    }
    trace({.kind = evt::not_found, .line = 3});
    return nil;
  }

}  // namespace se
