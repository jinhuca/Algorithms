module;

// Insertion sort — grow a sorted prefix by taking the next element as a "key" and
// shifting larger prefix elements one slot right until the key's spot opens up, then
// dropping it in. Stable, in-place, O(n²) worst case but O(n) on nearly-sorted input
// and very low overhead on small arrays. Emits the held key as a `cursor`, a compare
// per examined neighbour, and `overwrite` steps for each shift + the final drop — so
// the visualizer shows the gap sliding, not a swap.

export module sa.simple_sorts.insertion;

import std;
import sa.seq;
import sa.trace;

export namespace sa {
  template <sortable R, typename Compare = less>
  void insertion_sort(R& data, Compare cmp = {}, const tracer& trace = ignore) {
    using T = std::ranges::range_value_t<R>;
    auto a = std::ranges::begin(data);           // mutable random-access iterator: a[i] is element i
    const std::size_t n = std::ranges::size(data);
    for(std::size_t i = 1; i < n; ++i) {
      T key = a[i];
      const double kv = value_of(key);
      trace({.kind = evt::cursor, .i = i, .value = kv, .line = 1});
      std::size_t j = i;
      while(j > 0) {
        trace({.kind = evt::compare, .i = j - 1, .j = i, .line = 3});
        if(cmp(key, a[j - 1])) {
          a[j] = a[j - 1];                        // shift the larger element up
          trace({.kind = evt::overwrite, .i = j, .value = value_of(a[j]), .line = 4});
          --j;
        }
        else {
          break;
        }
      }
      a[j] = key;                                 // drop the key into the gap
      trace({.kind = evt::overwrite, .i = j, .value = kv, .line = 5});
    }
    if(n > 0) trace({.kind = evt::mark_sorted, .i = 0, .line = 0});
  }
}  // namespace sa
