module;

// Bubble sort — repeatedly walk the array swapping adjacent out-of-order pairs, so
// the largest remaining element "bubbles" to the end of each pass. Stable, in-place,
// O(n²) comparisons; O(n) best case on already-sorted input thanks to the early-exit
// when a pass makes no swaps. Emits compare / swap steps and marks each settled tail
// position, so a visualizer can animate the classic bubbling.

export module sa.simple_sorts.bubble;

import std;
import sa.seq;
import sa.trace;

export namespace sa {
  template <typename R, typename Compare = less>
    requires sortable<R, Compare>
  void bubble_sort(R& data, Compare cmp = {}, const tracer& trace = ignore) {
    auto a = std::ranges::begin(data);           // mutable random-access iterator: a[i] is element i
    const std::size_t n = std::ranges::size(data);
    for(std::size_t end = n; end > 1; --end) {
      bool swapped = false;
      for(std::size_t i = 0; i + 1 < end; ++i) {
        trace({.kind = evt::compare, .i = i, .j = i + 1, .line = 2});
        if(cmp(a[i + 1], a[i])) {
          std::swap(a[i], a[i + 1]);
          trace({.kind = evt::swap, .i = i, .j = i + 1, .line = 3});
          swapped = true;
        }
      }
      trace({.kind = evt::mark_sorted, .i = end - 1, .line = 4});
      trace({.kind = evt::pass_boundary, .note = "pass complete", .line = 0});
      if(!swapped) break;        // no swaps -> the whole array is already ordered
    }
    if(n > 0) trace({.kind = evt::mark_sorted, .i = 0, .line = 4});
  }
}  // namespace sa
