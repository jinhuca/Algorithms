module;

// Shell sort — insertion sort generalised to compare-and-shift elements a "gap"
// apart, with the gap shrinking to 1 on the final pass (a plain insertion sort by
// then, but on an almost-sorted array). Early large gaps move elements a long way
// cheaply, breaking up the "turtles" that make insertion sort slow, so it runs in
// roughly O(n log²n) with the Knuth gap sequence (1, 4, 13, 40, …) used here. In-
// place, not stable. Emits the held key as a `cursor`, a compare per gapped
// neighbour, and `overwrite` steps for each shift — so the visualizer shows the
// gapped passes tightening.

#include <vector>

export module sa.advanced_sorts.shell;

import sa.seq;
import sa.trace;

export namespace sa {

  template <class T, class Compare = less>
  void shell_sort(std::vector<T>& a, Compare cmp = {}, const tracer& trace = ignore) {
    const std::size_t n = a.size();
    if (n < 2) { if (n == 1) trace({.kind = evt::mark_sorted, .i = 0, .line = 0}); return; }

    std::size_t gap = 1;                       // largest Knuth gap < n/3
    while (gap < n / 3) gap = gap * 3 + 1;

    for (; gap >= 1; gap /= 3) {
      for (std::size_t i = gap; i < n; ++i) {
        T key = a[i];
        const double kv = value_of(key);
        trace({.kind = evt::cursor, .i = i, .value = kv, .line = 2});
        std::size_t j = i;
        while (j >= gap) {
          trace({.kind = evt::compare, .i = j - gap, .j = i, .line = 3});
          if (cmp(key, a[j - gap])) {
            a[j] = a[j - gap];
            trace({.kind = evt::overwrite, .i = j, .value = value_of(a[j]), .line = 4});
            j -= gap;
          } else {
            break;
          }
        }
        a[j] = key;
        trace({.kind = evt::overwrite, .i = j, .value = kv, .line = 5});
      }
      trace({.kind = evt::pass_boundary, .value = static_cast<double>(gap), .note = "gap pass", .line = 0});
      if (gap == 1) break;                     // avoid unsigned 1/3 == 0 underflow loop
    }
    trace({.kind = evt::mark_sorted, .i = 0, .line = 0});
  }

}  // namespace sa
