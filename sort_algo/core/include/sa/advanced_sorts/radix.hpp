#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of radix.ixx (the C++20 module), produced by
// scripts/gen_sa_hpp.py. The .ixx is the source of truth: edit it and re-run
//   py -I scripts/gen_sa_hpp.py
// This header lets the Qt/MinGW app and the tests use the sa core without
// C++20 modules / `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "sa core requires a C++20 compiler (GCC >= 11)."
#endif

// Radix sort (LSD, base 256) — the non-comparison sort. Instead of comparing pairs,
// it distributes elements into 256 buckets by one byte of an order-preserving 64-bit
// key, least-significant byte first, repeating for each byte; because each pass is
// stable, after the last byte the array is fully ordered. Runs in O(d·(n+256)) with
// d = key bytes — linear in n, independent of the data's order — but needs O(n) extra
// space and only applies to keys mappable to integers (here: any arithmetic T, via a
// monotonic bit transform that also handles negatives and floating point). Stable,
// not in-place, and does ZERO comparisons — a useful contrast in the Analyzer. Emits
// `read` while keying and `overwrite` as each distribution pass rewrites the array.

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
  // Map an element to a 64-bit key whose unsigned order matches the value's natural
  // order — for unsigned, signed (flip sign bit) and floating (IEEE bit transform).
  template <typename T>
  inline std::uint64_t radix_key(const T& x) {
    if constexpr(std::is_integral_v<T>) {
      if constexpr(std::is_signed_v<T>)
        return static_cast<std::uint64_t>(static_cast<std::int64_t>(x)) ^ 0x8000000000000000ULL;
      else
        return static_cast<std::uint64_t>(x);
    }
    else {
      const std::uint64_t b = std::bit_cast<std::uint64_t>(static_cast<double>(x));
      const std::uint64_t mask = (b >> 63) ? ~0ULL : 0x8000000000000000ULL;
      return b ^ mask;   // negatives -> below positives, order preserved
    }
  }

  template <arithmetically_sortable R>
  void radix_sort(R& data, const tracer& trace = ignore) {
    using T = std::ranges::range_value_t<R>;
    const std::size_t n = std::ranges::size(data);
    auto out = std::ranges::begin(data);
    if(n < 2) { if(n == 1) trace({.kind = evt::mark_sorted, .i = 0, .line = 1}); return; }

    std::vector<T> a(n);                       // radix is not in-place: sort a working copy,
    for(std::size_t i = 0; i < n; ++i) a[i] = out[i];    // then write the result back below

    std::vector<std::uint64_t> keys(n);
    for(std::size_t i = 0; i < n; ++i) {
      keys[i] = radix_key(a[i]);
      trace({.kind = evt::read, .i = i, .value = value_of(a[i]), .line = 0});
    }

    std::vector<T> outA(n);
    std::vector<std::uint64_t> outK(n);
    for(int shift = 0; shift < 64; shift += 8) {
      std::size_t count[256] = {0};
      for(std::size_t i = 0; i < n; ++i) ++count[(keys[i] >> shift) & 0xFF];
      if(count[(keys[0] >> shift) & 0xFF] == n) continue;   // all share this byte -> no-op pass

      std::size_t offset[256];
      std::size_t sum = 0;
      for(int b = 0; b < 256; ++b) { offset[b] = sum; sum += count[b]; }

      for(std::size_t i = 0; i < n; ++i) {
        const std::size_t b = (keys[i] >> shift) & 0xFF;
        const std::size_t pos = offset[b]++;
        outA[pos] = a[i];
        outK[pos] = keys[i];
      }
      std::swap(a, outA);
      std::swap(keys, outK);
      for(std::size_t i = 0; i < n; ++i)
        trace({.kind = evt::overwrite, .i = i, .value = value_of(a[i]), .line = 4});
      trace({.kind = evt::pass_boundary, .value = static_cast<double>(shift / 8), .note = "digit pass", .line = 1});
    }
    for(std::size_t i = 0; i < n; ++i) out[i] = a[i];    // copy the sorted working copy back into the range
    trace({.kind = evt::mark_sorted, .i = 0, .line = 1});
  }
}  // namespace sa
