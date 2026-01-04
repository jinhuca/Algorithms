import InsertionSort;
import std;

template<typename T>
  requires std::totally_ordered<T>
void insert_sort(std::vector<T> vec){
  std::cout << "Insertion Sort: ";
}