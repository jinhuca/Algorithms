#pragma once
#include <vector>
#include <algorithm> // for std::swap and std::less
#include <iterator>  // for std::iterator_traits

// General implementation for custom comparator
template <class It, class Compare>
void insertion_sort(It first, It last, Compare cmp) {
  for(It i = first; i != last; ++i) {
    It key = i;
    // Move elements of the sorted portion, that are greater than the key element,
    // to one position ahead of their current position
    while(key != first && cmp(*key, *(std::prev(key)))) {
      std::swap(*key, *(std::prev(key)));
      --key;
    }
  }
}

// Overload for default comparison (using operator<)
template <class It>
void insertion_sort(It first, It last) {
  // Determine the value type to use std::less with
  typedef typename std::iterator_traits<It>::value_type value_type;
  insertion_sort(first, last, std::less<value_type>());
}