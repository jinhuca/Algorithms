module;

// Binary search — the archetypal sorted-array search. Keep a half-open window
// [lo, hi); probe the midpoint and discard the half that cannot contain the target.
// Requires the array sorted by the same comparator. O(log n) comparisons, O(1) space.
// Emits lo_bound / hi_bound as the window narrows, a mid + probe at each midpoint, and
// an eliminate for the discarded half, so a visualizer shows the window collapsing.

#include <vector>

export module se.sorted_searches.binary;

import se.seq;
import se.trace;

export namespace se {

  template <class T, class Compare = less>
  index binary_search(const std::vector<T>& a, const T& target,
                      Compare cmp = {}, const tracer& trace = ignore) {
    std::size_t lo = 0, hi = a.size();           // window is [lo, hi)
    while (lo < hi) {
      const std::size_t mid = lo + (hi - lo) / 2;
      trace({.kind = evt::mid, .i = mid, .value = value_of(a[mid]), .line = 2});
      trace({.kind = evt::probe, .i = mid, .value = value_of(a[mid]), .line = 2});
      if (cmp(a[mid], target)) {                 // a[mid] < target -> answer is to the right
        trace({.kind = evt::eliminate, .i = lo, .j = mid, .line = 3});
        lo = mid + 1;
        trace({.kind = evt::lo_bound, .i = lo, .line = 3});
      } else if (cmp(target, a[mid])) {          // target < a[mid] -> answer is to the left
        trace({.kind = evt::eliminate, .i = mid, .j = hi - 1, .line = 4});
        hi = mid;
        if (hi > 0) trace({.kind = evt::hi_bound, .i = hi - 1, .line = 4});
      } else {
        trace({.kind = evt::found, .i = mid, .value = value_of(a[mid]), .line = 5});
        return mid;
      }
    }
    trace({.kind = evt::not_found, .line = 6});
    return nil;
  }

}  // namespace se
