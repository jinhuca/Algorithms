module;

// sa::seq — the sequence foundation for the sort core.
//
// Sorting works on a 1-D sequence of elements. Unlike a graph, the data structure
// is just a contiguous, index-addressable range (a std::vector<T> in practice), so
// this module carries only the small shared vocabulary every sort needs:
//
//   * sa::index / sa::nil — a position in the sequence (0..size-1), mirroring
//     ga::vertex / ga::nil in the graph core.
//   * sa::sortable<R>     — the C++20 concept that constrains the generic sorts:
//     a random-access range whose element type is totally ordered. This is the
//     "concept for generic programming" the spec asks for.
//   * sa::less            — the default comparator, so every algorithm is generic
//     over an arbitrary strict-weak-ordering Compare.
//
// Presentation data — bar colours, positions, the chosen palette — deliberately
// lives OUTSIDE the core, in the visualizer, so the core stays a pure, allocation-
// light computation layer (the same split as the graph studio's core).

#include <compare>
#include <concepts>
#include <cstddef>
#include <functional>
#include <ranges>

export module sa.seq;

export namespace sa {

  using index = std::size_t;
  inline constexpr index nil = static_cast<index>(-1);   // "no position"

  // The element contract: values must be totally ordered so a comparator can put
  // them in a well-defined order.
  template <class T>
  concept orderable = std::totally_ordered<T>;

  // The range contract for a generic in-place sort: a random-access range (so the
  // algorithms can index + swap in O(1)) of orderable elements.
  template <class R>
  concept sortable =
      std::ranges::random_access_range<R> &&
      orderable<std::ranges::range_value_t<R>>;

  // Default comparator — ascending order. Every sort takes a Compare defaulting to
  // this, so a caller can pass std::greater, a projection, etc.
  using less = std::less<>;

}  // namespace sa
