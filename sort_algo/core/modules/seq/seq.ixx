module;

// sa::seq — the sequence foundation for the sort core.
//
// Sorting works on a 1-D sequence of elements. Unlike a graph, the data structure
// is just a contiguous, index-addressable range (a std::vector<T> in practice), so
// this module carries only the small shared vocabulary every sort needs:
//
//   * sa::index / sa::nil — a position in the sequence (0..size-1), mirroring
//     ga::vertex / ga::nil in the graph core.
//   * sa::sortable<R, Compare> — the C++20 concept constraining the COMPARISON sorts:
//     a mutable random-access range whose iterator is std::sortable under Compare.
//     counting_sortable / arithmetically_sortable constrain the non-comparison sorts.
//     This is the "concept for generic programming" the spec asks for.
//   * sa::less            — the default comparator, so every comparison sort is generic
//     over an arbitrary strict-weak-ordering Compare.
//
// Presentation data — bar colours, positions, the chosen palette — deliberately
// lives OUTSIDE the core, in the visualizer, so the core stays a pure, allocation-
// light computation layer (the same split as the graph studio's core).

export module sa.seq;

import std;

export namespace sa {

  using index = std::size_t;
  inline constexpr index nil = static_cast<index>(-1);   // "no position"

  // Default comparator — ascending order. Every comparison sort takes a Compare
  // defaulting to this, so a caller can pass std::greater, a projection, etc.
  using less = std::less<>;

  // A comparator usable by a sort: Compare imposes a strict weak ordering on element
  // type E. That is the ENTIRE element requirement for a comparison sort — the elements
  // need NOT be std::totally_ordered themselves; a custom Compare (std::greater, a
  // projection, a type with no operator<) is enough. The default case — relying on
  // operator< via sa::less — is `orderable`.
  template <typename Compare, typename E>
  concept comparator_for = std::strict_weak_order<const Compare&, const E&, const E&>;

  // An element orderable by the default comparator (operator< via sa::less).
  template <typename E>
  concept orderable = comparator_for<less, E>;

  // The contract for the COMPARISON sorts: a random-access range (index + reorder in
  // O(1)) whose iterator is std::sortable under Compare — the standard concept that
  // already bundles "permutable" (movable + swappable, so the range must be MUTABLE,
  // not const) with an indirect strict-weak-order. The "concept for generic
  // programming" the spec asks for, expressed through the standard std::sortable.
  template <typename R, typename Compare = less>
  concept sortable =
    std::ranges::random_access_range<R> &&
    std::sortable<std::ranges::iterator_t<R>, Compare>;

  // The contract for counting_sort: it tallies keys in an ordered std::map, so it needs
  // only orderable (default-comparable) elements over a random-access range — no
  // in-place permutation and no custom comparator.
  template <typename R>
  concept counting_sortable =
    std::ranges::random_access_range<R> &&
    orderable<std::ranges::range_value_t<R>>;

  // The contract for the DISTRIBUTION sorts (radix, bucket): a random-access range of
  // arithmetic elements, since they key / bin by numeric value rather than comparing.
  template <typename R>
  concept arithmetically_sortable =
    std::ranges::random_access_range<R> &&
    std::is_arithmetic_v<std::ranges::range_value_t<R>>;

}  // namespace sa
