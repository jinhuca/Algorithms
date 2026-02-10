#include "pch.h"
#include "CppUnitTest.h"

#include "../Sorting/Insertion_sort.h"

using namespace Microsoft::VisualStudio::CppUnitTestFramework;

namespace TestsSort {
  TEST_CLASS(TestsSort) {
public:
  TEST_METHOD(TestMethod1) {
    std::vector<int> int_data = {12, 11, 13, 5, 6};
    A02_Algorithm_Sort2::insertion_sort(int_data.begin(), int_data.end());
    std::vector<int> expected_data = {5, 6, 11, 12, 13};
    Assert::IsTrue(int_data == expected_data);
  }
  };
}
