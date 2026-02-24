// A01_Insertion_Sort.cpp 
import std;
import A01_Insertion_Sort_Cpp20_Iterators;
import A01_Insertion_Sort_Cpp20_Ranges;
//#include <iostream>
//#include "Person.h"
//#include "A01_Insertion_Sort_Cpp98.h"

//void test_Cpp98() {
//  std::vector<int> data = {5, 2, 9, 1, 5, 6};
//  std::cout << "Before sorting: ";
//  for(size_t i = 0; i < data.size(); ++i) {
//    std::cout << data[i] << " ";
//  }
//  insertion_sort(data.begin(), data.end());
//  std::cout << "\nAfter sorting: ";
//  for(size_t i = 0; i < data.size(); ++i) {
//    std::cout << data[i] << " ";
//  }
//
//  std::vector<Person> people = {
//    Person("Alice", 30),
//    Person("Bob", 25),
//    Person("Charlie", 35)
//  };
//  std::cout << "\nBefore sorting people by age:\n";
//  for(size_t i = 0; i < people.size(); ++i) {
//    std::cout << people[i].name << " (" << people[i].age << ")\n";
//  }
//  insertion_sort(people.begin(), people.end());
//  std::cout << "After sorting people by age:\n";
//  for(size_t i = 0; i < people.size(); ++i) {
//    std::cout << people[i].name << " (" << people[i].age << ")\n";
//  }
//}

void test_Cpp20_Iterators() {
  std::vector<int> data = {5, 2, 9, 1, 5, 6};
  //std::vector<int> data2 = {3, 8, 7, 4, 2, 1};
  std::cout << "Before sorting: ";
  for(const auto& num : data) {
    std::cout << num << " ";
  }
  A01_Insertion_Sort_Cpp20_Iterators::insertion_sort(data.begin(), data.end());
  //A01_Insertion_Sort_Cpp20_Iterators::insertion_sort(data.begin(), data.end());
  std::cout << "\nAfter sorting: ";
  for(const auto& num : data) {
    std::cout << num << " ";
  }

  int arr[] = {3, 8, 7, 4, 2, 1};
  std::cout << "\nBefore sorting array: ";
  for(const auto& num : arr) {
    std::cout << num << " ";
  }
  A01_Insertion_Sort_Cpp20_Iterators::insertion_sort(std::begin(arr), std::end(arr));
  std::cout << "\nAfter sorting array: ";
  for(const auto& num : arr) {
    std::cout << num << " ";
  }
}

void test_Cpp20_Ranges() {
  std::vector<int> data = {5, 2, 9, 1, 5, 6};
  std::cout << "Before sorting: ";
  for(const auto& num : data) {
    std::cout << num << " ";
  }
  //A01_Insertion_Sort_Cpp20_Ranges::insertion_sort(data);
  std::cout << "\nAfter sorting: ";
  for(const auto& num : data) {
    std::cout << num << " ";
  }
}

int main() {
  //test_Cpp98();
  test_Cpp20_Iterators();
  //test_Cpp20_Iterators();
}
