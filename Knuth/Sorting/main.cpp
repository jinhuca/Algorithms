// Sorting.cpp 
import std;
import A02_Algorithm_Sort;

int main() {
  std::vector<int> int_data = {12, 11, 13, 5, 6};
  std::cout << "Original array: ";
  for (const auto& num : int_data) {
    std::cout << num << " ";
  }
  A02_Algorithm_Sort::insertion_sort(int_data.begin(), int_data.end());
  std::cout << "\nSorted array: ";
  for (const auto& num : int_data) {
    std::cout << num << " ";
  }
}
