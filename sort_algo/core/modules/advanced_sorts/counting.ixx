module;

// Counting sort — the archetypal non-comparison sort. Tally how many times each key
// occurs, then write the keys back in order, each repeated by its count. With a small
// integer key range [0, k] that tally is a flat array and the whole sort is O(n + k),
// beating the comparison lower bound; it is stable and does no key comparisons. This
// implementation keeps the keys in an ordered map so it stays correct for ANY
// comparable value (not just a dense integer range) — it then shines exactly when
// there are few distinct keys (the "few unique" workload). Emits a `read` as it tallies
// each element and an `overwrite` as it writes the sorted output. Ascending only.

#include <cstddef>
#include <map>
#include <vector>

export module sa.advanced_sorts.counting;

import sa.seq;
import sa.trace;

export namespace sa {

  template <class T>
  void counting_sort(std::vector<T>& a, const tracer& trace = ignore) {
    const std::size_t n = a.size();
    if (n < 2) { if (n == 1) trace({.kind = evt::mark_sorted, .i = 0, .line = 1}); return; }

    std::map<T, std::size_t> counts;                  // key -> occurrences (ordered)
    for (std::size_t i = 0; i < n; ++i) {
      ++counts[a[i]];
      trace({.kind = evt::read, .i = i, .value = value_of(a[i]), .line = 0});
    }

    std::size_t pos = 0;
    for (const auto& [key, cnt] : counts)
      for (std::size_t c = 0; c < cnt; ++c) {
        a[pos] = key;
        trace({.kind = evt::overwrite, .i = pos, .value = value_of(a[pos]), .line = 2});
        ++pos;
      }
    trace({.kind = evt::mark_sorted, .i = 0, .line = 1});
  }

}  // namespace sa
