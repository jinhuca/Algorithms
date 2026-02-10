export module A01_Insertion_Sort_Cpp20_Iterators;
import std;

namespace A01_Insertion_Sort_Cpp20_Iterators {
  export template<typename Iterator>
    concept BidirectionalIterator = std::bidirectional_iterator<Iterator>;

  export template<typename iterator_t>
    concept SortableValue = std::totally_ordered<typename std::iterator_traits<iterator_t>::value_type>;
  
  export template<BidirectionalIterator iterator>
    requires SortableValue<iterator>
  void insertion_sort(iterator first, iterator last) {
    if(first == last) return;   // empty range
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
}  // namespace A01_Insertion_Sort_Cpp20_Iterators
