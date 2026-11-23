#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of seq.ixx (the C++20 module), produced by
// scripts/gen_se_hpp.py. The .ixx is the source of truth: edit it and re-run
//   py -I scripts/gen_se_hpp.py
// This header lets the Qt/MinGW app and the tests use the se core without
// C++20 modules / `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "se core requires a C++20 compiler (GCC >= 11)."
#endif

// se::seq — the sequence foundation for the search core.
//
// Searching works on a 1-D sequence of elements. The data structure is just a
// contiguous, index-addressable range (a std::vector<T> in practice), so this module
// carries only the small shared vocabulary every search needs:
//
//   * se::index / se::nil — a position in the sequence (0..size-1). A search returns
//     se::nil when the target is absent, mirroring ga::nil / sa::nil.
//   * se::searchable<R, Compare> / se::sorted_searchable<R, Compare> — the C++20
//     concepts that constrain the generic searches: a sized forward range whose
//     elements a Compare can strict-weak-order (searchable — the sequential searches),
//     refined with random access for O(1) midpoint probing (sorted_searchable — the
//     sorted searches). This is the "concept for generic programming" the spec asks for.
//   * se::less            — the default comparator, so every algorithm is generic over
//     an arbitrary strict-weak-ordering Compare (the order the data is sorted by).
//   * se::equivalent      — one shared notion of "found": a and b match when neither
//     orders before the other (no separate operator== required).
//
// Presentation data — bar colours, probe markers, the chosen palette — deliberately
// lives OUTSIDE the core, in the visualizer, so the core stays a pure, allocation-
// light computation layer (the same split as the sort / graph studios' cores).

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

namespace se {
  using index = std::size_t;
  inline constexpr index nil = static_cast<index>(-1);   // "not found" / "no position"

  // Default comparator — ascending order. Every search takes a Compare defaulting to
  // this, so it is generic over whatever strict-weak-ordering the data is sorted by
  // (pass std::greater for a descending array, a projection, ...).
  using less = std::less<>;

  // A comparator usable by a search: Compare imposes a strict weak ordering on element
  // type E. That is the ENTIRE element requirement — from a strict weak order a search
  // derives both "equivalent" (neither cmp(a,b) nor cmp(b,a)) and, for the sorted
  // searches, which half to keep. The elements need NOT be std::totally_ordered
  // themselves: a custom Compare (std::greater, a projection, a type with no operator<)
  // is enough. The default case — relying on operator< via se::less — is `orderable`.
  template <typename Compare, typename E>
  concept comparator_for = std::strict_weak_order<const Compare&, const E&, const E&>;

  // An element orderable by the default comparator (operator< via se::less).
  template <typename E>
  concept orderable = comparator_for<less, E>;

  // The contract EVERY search shares: a sized, forward range whose elements a Compare
  // can order. `sized` + `forward` (not random-access) because a search returns an
  // se::index position and reports a[i] to the tracer — the positional model needs a
  // known size, but linear / sentinel need only a single forward pass.
  template <typename R, typename Compare = less>
  concept searchable =
    std::ranges::forward_range<R> &&
    std::ranges::sized_range<R> &&
    comparator_for<Compare, std::ranges::range_value_t<R>>;

  // The extra contract for the sorted searches: O(1) random access, so they can probe
  // an arbitrary midpoint (binary / ternary / interpolation / jump / exponential /
  // fibonacci) instead of stepping. On a merely-forward range they would stay correct
  // but degrade to O(n) advances — the reason std::lower_bound on a std::list is O(n).
  template <typename R, typename Compare = less>
  concept sorted_searchable =
    searchable<R, Compare> &&
    std::ranges::random_access_range<R>;

  // Equivalence under a strict-weak-ordering comparator: a and b are "equal" for the
  // purpose of searching when neither orders before the other. Lets every algorithm
  // share one notion of "found" without requiring a separate operator==.
  template <typename T, typename Compare>
  inline bool equivalent(const T& a, const T& b, Compare& cmp) {
    return !cmp(a, b) && !cmp(b, a);
  }
}  // namespace se
