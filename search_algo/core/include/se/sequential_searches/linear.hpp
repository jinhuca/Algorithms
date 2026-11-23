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

#include <algorithm>
#include <bit>
#include <chrono>
#include <cmath>
#include <compare>
#include <concepts>
#include <cstddef>
#include <cstdint>
#include <functional>
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
  template <searchable R, typename Compare = less>
  index linear_search(const R& data, const std::ranges::range_value_t<R>& target,
    Compare cmp = {}, const tracer& trace = ignore) {
    index i = 0;
    for(const auto& x : data) {                 // one forward pass — no random access needed
      trace({.kind = evt::probe, .i = i, .value = value_of(x), .line = 1});
      if(equivalent(x, target, cmp)) {
        trace({.kind = evt::found, .i = i, .value = value_of(x), .line = 2});
        return i;
      }
      ++i;
    }
    trace({.kind = evt::not_found, .line = 3});
    return nil;
  }
}  // namespace se
