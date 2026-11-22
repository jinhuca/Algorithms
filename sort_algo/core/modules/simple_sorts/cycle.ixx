module;

// Cycle sort — the write-optimal sort: each element is written to its final slot
// exactly once, so the total number of writes is the theoretical minimum (useful
// when writes are far more expensive than reads, e.g. flash/EEPROM). For each start
// position it counts how many elements are smaller to find where the held item
// belongs, places it there (displacing the next item), and follows that cycle until
// it closes. In-place, not stable, Θ(n²) comparisons. Emits compares as it counts,
// and an `overwrite` for every (minimal) placement — so the visualizer shows items
// hopping straight to their home.

#include <utility>
#include <vector>

export module sa.simple_sorts.cycle;

import sa.seq;
import sa.trace;

export namespace sa {

  template <class T, class Compare = less>
  void cycle_sort(std::vector<T>& a, Compare cmp = {}, const tracer& trace = ignore) {
    const std::size_t n = a.size();
    // Equivalence under a strict-weak-ordering comparator (for skipping duplicates),
    // so the algorithm stays correct for an arbitrary Compare, not just operator<.
    auto equiv = [&](const T& x, const T& y) { return !cmp(x, y) && !cmp(y, x); };

    for (std::size_t start = 0; start + 1 < n; ++start) {
      T item = a[start];
      trace({.kind = evt::cursor, .i = start, .value = value_of(item), .line = 1});

      // Where does `item` belong? Count the elements after `start` that are smaller.
      std::size_t pos = start;
      for (std::size_t i = start + 1; i < n; ++i) {
        trace({.kind = evt::compare, .i = i, .j = start, .line = 2});
        if (cmp(a[i], item)) ++pos;
      }
      if (pos == start) continue;                 // already in place -> no cycle

      while (equiv(item, a[pos])) ++pos;          // place after any equal elements
      std::swap(item, a[pos]);
      trace({.kind = evt::overwrite, .i = pos, .value = value_of(a[pos]), .line = 4});

      // Rotate the rest of the cycle until the displaced item returns to `start`.
      while (pos != start) {
        pos = start;
        for (std::size_t i = start + 1; i < n; ++i) {
          trace({.kind = evt::compare, .i = i, .j = start, .line = 2});
          if (cmp(a[i], item)) ++pos;
        }
        while (equiv(item, a[pos])) ++pos;
        std::swap(item, a[pos]);
        trace({.kind = evt::overwrite, .i = pos, .value = value_of(a[pos]), .line = 5});
      }
    }
    if (n > 0) trace({.kind = evt::mark_sorted, .i = 0, .line = 0});
  }

}  // namespace sa
