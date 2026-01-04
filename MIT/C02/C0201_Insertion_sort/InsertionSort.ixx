export module InsertionSort;
import std;

//export template<typename T>
//  requires std::totally_ordered<T>
//void insert_sort(std::vector<T> vec) {
//  std::cout << "Insertion Sort: ";
//}

export template<typename ElementType>
  requires std::totally_ordered<ElementType>
void insertion_sort(std::vector<ElementType> vec) {
  for(std::size_t i {1}; i < vec.size(); ++i) {
    ElementType key = vec[i];
    std::size_t j = i;
    while(j > 0 && vec[j - 1] > key) {
      vec[j] = vec[j - 1];
      --j;
    }
    vec[j] = key;
  }
  for(const auto& element : vec) {
    std::cout << element << " ";
  }
  std::cout << std::endl;
}

template <typename BidirectionalIterator,
  typename Compare = std::less<typename std::iterator_traits<BidirectionalIterator>::value_type>>
  void insertion_sort(BidirectionalIterator first, BidirectionalIterator last, Compare comp = Compare()) {
  if(first == last) return;

  for(auto i = std::next(first); i != last; ++i) {
    auto key = std::move(*i); // Use move for efficiency
    auto j = i;
    auto prev = std::prev(j);

    // Move elements of [first, i-1] that are greater than key 
    // to one position ahead of their current position
    while(j != first && comp(key, *prev)) {
      *j = std::move(*prev);
      --j;
      if(j != first) --prev;
    }
    *j = std::move(key);
  }
}