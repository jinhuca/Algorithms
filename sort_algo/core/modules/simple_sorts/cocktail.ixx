module;

// Cocktail shaker sort — bidirectional bubble sort. Each round bubbles the largest
// remaining element up to the right end, then the smallest down to the left end, so
// the sorted region grows from both sides and small values near the end ("turtles")
// reach home far faster than in plain bubble sort. Stable, in-place, O(n²), with the
// same no-swap early exit. Emits compares, swaps, and marks both settling ends.

export module sa.simple_sorts.cocktail;

import std;
import sa.seq;
import sa.trace;

export namespace sa {
  template <sortable R, typename Compare = less>
  void cocktail_sort(R& data, Compare cmp = {}, const tracer& trace = ignore) {
    auto a = std::ranges::begin(data);           // mutable random-access iterator: a[i] is element i
    const std::size_t n = std::ranges::size(data);
    if(n < 2) {
      if(n == 1) trace({.kind = evt::mark_sorted, .i = 0, .line = 0});
      return;
    }
    std::size_t lo = 0, hi = n - 1;
    bool swapped = true;
    while(swapped && lo < hi) {
      swapped = false;
      for(std::size_t i = lo; i < hi; ++i) {               // forward: bubble max up
        trace({.kind = evt::compare, .i = i, .j = i + 1, .line = 2});
        if(cmp(a[i + 1], a[i])) {
          std::swap(a[i], a[i + 1]);
          trace({.kind = evt::swap, .i = i, .j = i + 1, .line = 2});
          swapped = true;
        }
      }
      trace({.kind = evt::mark_sorted, .i = hi, .line = 1});
      --hi;
      trace({.kind = evt::pass_boundary, .note = "forward pass", .line = 1});
      if(!swapped) break;

      swapped = false;
      for(std::size_t i = hi; i > lo; --i) {               // backward: bubble min down
        trace({.kind = evt::compare, .i = i - 1, .j = i, .line = 4});
        if(cmp(a[i], a[i - 1])) {
          std::swap(a[i - 1], a[i]);
          trace({.kind = evt::swap, .i = i - 1, .j = i, .line = 4});
          swapped = true;
        }
      }
      trace({.kind = evt::mark_sorted, .i = lo, .line = 3});
      ++lo;
      trace({.kind = evt::pass_boundary, .note = "backward pass", .line = 3});
    }
    for(std::size_t k = lo; k <= hi && hi < n; ++k) trace({.kind = evt::mark_sorted, .i = k, .line = 0});
  }
}  // namespace sa
