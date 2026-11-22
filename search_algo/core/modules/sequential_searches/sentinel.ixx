module;

// Sentinel linear search — a linear search that drops the per-step bounds check by
// planting the target itself as a guard just past the data, so the scan loop only has
// to test one thing (equality): it is guaranteed to stop on the guard at the latest.
// Same O(n) comparisons as the plain linear search but fewer operations per step. To
// keep the input immutable (and the core allocation-explicit), the guard is appended
// to a local copy; a stop at a real index [0, n) is a find, a stop on the guard means
// the target is absent.

#include <vector>

export module se.sequential_searches.sentinel;

import se.seq;
import se.trace;

export namespace se {

  template <class T, class Compare = less>
  index sentinel_search(const std::vector<T>& a, const T& target,
                        Compare cmp = {}, const tracer& trace = ignore) {
    const std::size_t n = a.size();
    if (n == 0) { trace({.kind = evt::not_found, .line = 4}); return nil; }

    std::vector<T> b = a;      // const-safe sentinel: scan a copy with the target appended
    b.push_back(target);

    std::size_t i = 0;
    while (!equivalent(b[i], target, cmp)) {   // no bounds test: the guard always stops us
      trace({.kind = evt::probe, .i = i, .value = value_of(b[i]), .line = 2});
      ++i;
    }
    if (i < n) {               // stopped on a real element, not the guard
      trace({.kind = evt::probe, .i = i, .value = value_of(b[i]), .line = 2});
      trace({.kind = evt::found, .i = i, .value = value_of(b[i]), .line = 3});
      return i;
    }
    trace({.kind = evt::not_found, .line = 4});
    return nil;
  }

}  // namespace se
