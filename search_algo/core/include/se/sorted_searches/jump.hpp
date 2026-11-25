#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of jump.ixx (the C++20 module), produced by
//   py -I scripts/gen_hpp.py --project search_algo --ns se
// The .ixx is the source of truth: edit it and re-run the generator. This header
// lets the Qt/MinGW app and the tests use the se core without C++20 modules /
// `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "se core requires a C++20 compiler (GCC >= 11)."
#endif

// Jump search — on a sorted array, step forward in fixed blocks of ~√n until the block
// whose last element is >= the target is found, then linear-scan within that block.
// O(√n) comparisons — between linear and binary — with a forward-only, cache-friendly
// access pattern (it never jumps backward like binary search). Emits a probe at each
// block boundary (and an eliminate for each skipped block), then probes inside the
// final block.
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

namespace se {
  template <sorted_searchable R, typename Compare = less>
  index jump_search(const R& data, const std::ranges::range_value_t<R>& target,
    Compare cmp = {}, const tracer& trace = ignore) {
    const auto a = std::ranges::begin(data);     // random-access iterator: a[i] is the i-th element
    const std::size_t n = std::ranges::size(data);
    if(n == 0) { trace({.kind = evt::not_found, .line = 5}); return nil; }

    std::size_t block = static_cast<std::size_t>(std::sqrt(static_cast<double>(n)));
    if(block == 0) block = 1;

    std::size_t start = 0;
    while(start < n) {
      const std::size_t last = std::min(start + block, n) - 1;   // last index of this block
      trace({.kind = evt::probe, .i = last, .value = value_of(a[last]), .line = 2});
      if(!cmp(a[last], target)) break;                          // a[last] >= target -> may be here
      trace({.kind = evt::eliminate, .i = start, .j = last, .line = 3});
      start += block;
    }
    if(start >= n) { trace({.kind = evt::not_found, .line = 5}); return nil; }

    const std::size_t end = std::min(start + block, n);
    for(std::size_t i = start; i < end; ++i) {
      trace({.kind = evt::probe, .i = i, .value = value_of(a[i]), .line = 4});
      if(equivalent(a[i], target, cmp)) {
        trace({.kind = evt::found, .i = i, .value = value_of(a[i]), .line = 6});
        return i;
      }
      if(cmp(target, a[i])) break;                              // passed where target would be
    }
    trace({.kind = evt::not_found, .line = 5});
    return nil;
  }
}  // namespace se
