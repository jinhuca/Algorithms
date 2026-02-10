export module A02_Algorithm_Sort;
import std;

namespace A02_Algorithm_Sort {
  export template<typename Iterator>
    concept BidirectionalIterator = std::bidirectional_iterator<Iterator>;

  export template<typename Iter>
    concept SortableValue = std::totally_ordered<typename std::iterator_traits<Iter>::value_type>;

  // Template function constrained by concepts for insertion sort
  export template<BidirectionalIterator iterator>
    requires SortableValue<iterator>
  void insertion_sort(iterator first, iterator last) {
    if(first == last) return;
    for(iterator current = std::next(first); current != last; ++current) {
      // Store the value of the current element to insert
      typename std::iterator_traits<iterator>::value_type key = std::move(*current);
      iterator j = current;
      iterator previous = std::prev(j);

      // Shift elements greater than the key to the right
      while(j != first && *previous > key) {
        *j = std::move(*previous);
        j = previous;
        if(j != first) {
          previous = std::prev(j);
        }
      }
      // Insert the key into its correct position
      *j = std::move(key);
    }
  }
} // namespace A02_Algorithm_Sort
