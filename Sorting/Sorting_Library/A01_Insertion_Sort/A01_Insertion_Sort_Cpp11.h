#pragma once
#include <iostream>
#include <vector>
#include <algorithm> // Required for std::upper_bound and std::rotate
#include <iterator>  // Required for std::iterator_traits

/**
 * @brief Generic insertion sort function using iterators.
 *
 * @tparam ForwardIterator An iterator type that meets the ForwardIterator concept.
 * @tparam Compare A comparison function/functor (defaults to std::less for ascending order).
 * @param first The beginning iterator of the range.
 * @param last The end iterator of the range.
 * @param cmp The comparison object.
 */
template<typename ForwardIterator, typename Compare = std::less<typename std::iterator_traits<ForwardIterator>::value_type>>
void insertion_sort(ForwardIterator first, ForwardIterator last, Compare cmp = Compare()) {
  for(auto it = first; it != last; ++it) {
    // Find the correct insertion point for the current element *it
    // within the already sorted sub-range [first, it) using binary search (std::upper_bound)
    auto const insertion = std::upper_bound(first, it, *it, cmp);

    // Rotate the elements to insert *it into its correct position
    std::rotate(insertion, it, std::next(it));
  }
}