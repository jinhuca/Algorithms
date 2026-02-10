export module A01_Insertion_Sort_Cpp20_Ranges;
import std;

namespace A01_Insertion_Sort_Cpp20_Ranges {
  export template<typename T>
    concept SortableRange = std::ranges::forward_range<T> && std::sortable<std::ranges::iterator_t<T>>;
  export void insertion_sort(SortableRange auto&& range) {
    auto begin = std::ranges::begin(range);
    auto end = std::ranges::end(range);
    if(begin == end) return; // empty range
    for(auto it = std::next(begin); it != end; ++it) {
      auto insertion_point = std::upper_bound(begin, it, *it);
      std::ranges::rotate(insertion_point, it, std::next(it));
    }
  }
}  // namespace A01_Insertion_Sort_Cpp20_Ranges