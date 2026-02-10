#pragma once
#include <string>
struct Person {
  std::string name;
  int age;
  Person(const std::string& name, int age) : name(name), age(age) {}
  
  // Overload the less-than operator for sorting by age
  bool operator<(const Person& other) const {
    return age < other.age;
  }
};