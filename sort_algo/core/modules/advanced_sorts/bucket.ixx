module;

// Bucket sort — a distribution sort for numeric data. Scatter the n values into n
// buckets by where they fall in the [min, max] range, sort each (small) bucket with
// insertion sort, then concatenate the buckets in order. On data that's roughly
// uniform the buckets stay tiny and it runs in O(n) average; a skewed input that
// piles into one bucket degrades to insertion sort's O(n²). Stable, needs O(n) extra
// space, and only applies to values mappable to a numeric range (any arithmetic T).
// Emits a `read` as it scatters each value and an `overwrite` as it writes the sorted
// result back. Ascending only.

export module sa.advanced_sorts.bucket;

import std;
import sa.seq;
import sa.trace;

export namespace sa {
  template <arithmetically_sortable R>
  void bucket_sort(R& data, const tracer& trace = ignore) {
    using T = std::ranges::range_value_t<R>;
    auto a = std::ranges::begin(data);           // mutable random-access iterator: a[i] is element i
    const std::size_t n = std::ranges::size(data);
    if(n < 2) { if(n == 1) trace({.kind = evt::mark_sorted, .i = 0, .line = 0}); return; }

    T lo = a[0], hi = a[0];
    for(std::size_t i = 0; i < n; ++i) {
      trace({.kind = evt::read, .i = i, .value = value_of(a[i]), .line = 0});
      if(a[i] < lo) lo = a[i];
      if(a[i] > hi) hi = a[i];
    }
    if(!(hi > lo)) { trace({.kind = evt::mark_sorted, .i = 0, .line = 0}); return; }   // all equal

    const std::size_t B = n;
    const double span = static_cast<double>(hi) - static_cast<double>(lo);
    std::vector<std::vector<T>> buckets(B);
    for(std::size_t i = 0; i < n; ++i) {
      std::size_t b = static_cast<std::size_t>((static_cast<double>(a[i]) - static_cast<double>(lo)) / span * static_cast<double>(B));
      if(b >= B) b = B - 1;
      buckets[b].push_back(a[i]);
    }

    std::size_t pos = 0;
    for(auto& bk : buckets) {
      for(std::size_t i = 1; i < bk.size(); ++i) {   // stable insertion within the bucket
        T key = bk[i];
        std::size_t j = i;
        while(j > 0 && key < bk[j - 1]) { bk[j] = bk[j - 1]; --j; }
        bk[j] = key;
      }
      for(const T& v : bk) {
        a[pos] = v;
        trace({.kind = evt::overwrite, .i = pos, .value = value_of(a[pos]), .line = 3});
        ++pos;
      }
    }
    trace({.kind = evt::mark_sorted, .i = 0, .line = 0});
  }
}  // namespace sa
