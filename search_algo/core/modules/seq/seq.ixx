module;

// se::seq — the sequence foundation for the search core.
//
// Searching works on a 1-D sequence of elements. The data structure is just a
// contiguous, index-addressable range (a std::vector<T> in practice), so this module
// carries only the small shared vocabulary every search needs:
//
//   * se::index / se::nil — a position in the sequence (0..size-1). A search returns
//     se::nil when the target is absent, mirroring ga::nil / sa::nil.
//   * se::searchable<R>   — the C++20 concept that constrains the generic searches:
//     a random-access range whose element type is totally ordered, so a comparator can
//     both decide equivalence and bisect a sorted range. This is the "concept for
//     generic programming" the spec asks for.
//   * se::less            — the default comparator, so every algorithm is generic over
//     an arbitrary strict-weak-ordering Compare (the order the data is sorted by).
//   * se::equivalent      — one shared notion of "found": a and b match when neither
//     orders before the other (no separate operator== required).
//
// Presentation data — bar colours, probe markers, the chosen palette — deliberately
// lives OUTSIDE the core, in the visualizer, so the core stays a pure, allocation-
// light computation layer (the same split as the sort / graph studios' cores).

#include <compare>
#include <concepts>
#include <cstddef>
#include <functional>
#include <ranges>

export module se.seq;

export namespace se {

  using index = std::size_t;
  inline constexpr index nil = static_cast<index>(-1);   // "not found" / "no position"

  // The element contract: values must be totally ordered so a comparator can both
  // decide equivalence (neither a<b nor b<a) and bisect a sorted range.
  template <class T>
  concept orderable = std::totally_ordered<T>;

  // The range contract for a generic search: a random-access range (so the sorted
  // searches can probe any midpoint in O(1)) of orderable elements.
  template <class R>
  concept searchable =
      std::ranges::random_access_range<R> &&
      orderable<std::ranges::range_value_t<R>>;

  // Default comparator — ascending order. Every search takes a Compare defaulting to
  // this, so the sorted searches work on whatever strict-weak-ordering the data is
  // sorted by (pass std::greater for a descending array, a projection, ...).
  using less = std::less<>;

  // Equivalence under a strict-weak-ordering comparator: a and b are "equal" for the
  // purpose of searching when neither orders before the other. Lets every algorithm
  // share one notion of "found" without requiring a separate operator==.
  template <class T, class Compare>
  inline bool equivalent(const T& a, const T& b, Compare& cmp) {
    return !cmp(a, b) && !cmp(b, a);
  }

}  // namespace se
