module;

// Linear (sequential) search — walk the array front to back, comparing each element
// against the target, and return the first match. The only search that needs NO
// ordering: it works on unsorted data. O(n) comparisons worst / average, O(1) best
// (a match at the front). Emits a `probe` per element and a `found` / `not_found`, so
// a visualizer sweeps a cursor along the array.
export module se.sequential_searches.linear;

import std;
import se.seq;
import se.trace;

export namespace se {
  template <searchable R, typename Compare = less>
  index linear_search(const R& data, const std::ranges::range_value_t<R>& target,
    Compare cmp = {}, const tracer& trace = ignore) {
    index i = 0;
    for(const auto& x : data) {                 // one forward pass — no random access needed
      trace({.kind = evt::probe, .i = i, .value = value_of(x), .line = 1});
      if(equivalent(x, target, cmp)) {
        trace({.kind = evt::found, .i = i, .value = value_of(x), .line = 2});
        return i;
      }
      ++i;
    }
    trace({.kind = evt::not_found, .line = 3});
    return nil;
  }
}  // namespace se
