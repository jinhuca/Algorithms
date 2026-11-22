module;

// Jump search — on a sorted array, step forward in fixed blocks of ~√n until the block
// whose last element is >= the target is found, then linear-scan within that block.
// O(√n) comparisons — between linear and binary — with a forward-only, cache-friendly
// access pattern (it never jumps backward like binary search). Emits a probe at each
// block boundary (and an eliminate for each skipped block), then probes inside the
// final block.

#include <algorithm>
#include <cmath>
#include <vector>

export module se.sorted_searches.jump;

import se.seq;
import se.trace;

export namespace se {

  template <class T, class Compare = less>
  index jump_search(const std::vector<T>& a, const T& target,
                    Compare cmp = {}, const tracer& trace = ignore) {
    const std::size_t n = a.size();
    if (n == 0) { trace({.kind = evt::not_found, .line = 5}); return nil; }

    std::size_t block = static_cast<std::size_t>(std::sqrt(static_cast<double>(n)));
    if (block == 0) block = 1;

    std::size_t start = 0;
    while (start < n) {
      const std::size_t last = std::min(start + block, n) - 1;   // last index of this block
      trace({.kind = evt::probe, .i = last, .value = value_of(a[last]), .line = 2});
      if (!cmp(a[last], target)) break;                          // a[last] >= target -> may be here
      trace({.kind = evt::eliminate, .i = start, .j = last, .line = 3});
      start += block;
    }
    if (start >= n) { trace({.kind = evt::not_found, .line = 5}); return nil; }

    const std::size_t end = std::min(start + block, n);
    for (std::size_t i = start; i < end; ++i) {
      trace({.kind = evt::probe, .i = i, .value = value_of(a[i]), .line = 4});
      if (equivalent(a[i], target, cmp)) {
        trace({.kind = evt::found, .i = i, .value = value_of(a[i]), .line = 6});
        return i;
      }
      if (cmp(target, a[i])) break;                              // passed where target would be
    }
    trace({.kind = evt::not_found, .line = 5});
    return nil;
  }

}  // namespace se
