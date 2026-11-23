// Module-based smoke test for the sa core, built by sort_algo.slnx. Unlike the
// header-based core/tests/test_core.cpp (which the MinGW/CMake build compiles
// against the generated .hpp), this one `import`s the C++20 modules directly, so it
// exercises the real module build (seq + family static libs via references).

//#include <algorithm>
//#include <cstdio>
//#include <functional>
//#include <vector>

import std;
import sa.seq;
import sa.trace;
import sa.simple_sorts.bubble;
import sa.simple_sorts.selection;
import sa.simple_sorts.insertion;
import sa.simple_sorts.cocktail;
import sa.simple_sorts.cycle;
import sa.efficient_sorts.merge;
import sa.efficient_sorts.quick;
import sa.efficient_sorts.heap;
import sa.advanced_sorts.shell;
import sa.advanced_sorts.radix;
import sa.advanced_sorts.counting;
import sa.advanced_sorts.bucket;
import sa.gen;
import sa.bench;

static int failures = 0;
#define CHECK(cond)                                                       \
    do {                                                                  \
        if (!(cond)) {                                                    \
            std::printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, #cond);   \
            ++failures;                                                   \
        }                                                                 \
    } while (0)

int main() {
  const std::vector<double> input = {5, 3, 8, 1, 9, 2, 7, 4, 6, 0};

  auto check_sorts = [&](auto sortfn, const char* name) {
    std::vector<double> a = input;
    sortfn(a);
    if(!std::is_sorted(a.begin(), a.end()))
      std::printf("FAIL %s did not sort\n", name);
    CHECK(std::is_sorted(a.begin(), a.end()));
  };
  check_sorts([](std::vector<double>& a) { sa::bubble_sort(a); }, "bubble");
  check_sorts([](std::vector<double>& a) { sa::selection_sort(a); }, "selection");
  check_sorts([](std::vector<double>& a) { sa::insertion_sort(a); }, "insertion");
  check_sorts([](std::vector<double>& a) { sa::cocktail_sort(a); }, "cocktail");
  check_sorts([](std::vector<double>& a) { sa::cycle_sort(a); }, "cycle");
  check_sorts([](std::vector<double>& a) { sa::merge_sort(a); }, "merge");
  check_sorts([](std::vector<double>& a) { sa::quick_sort(a); }, "quick");
  check_sorts([](std::vector<double>& a) { sa::heap_sort(a); }, "heap");
  check_sorts([](std::vector<double>& a) { sa::shell_sort(a); }, "shell");
  check_sorts([](std::vector<double>& a) { sa::radix_sort(a); }, "radix");
  check_sorts([](std::vector<double>& a) { sa::counting_sort(a); }, "counting");
  check_sorts([](std::vector<double>& a) { sa::bucket_sort(a); }, "bucket");

  // gen + bench wired together, as the Analyzer uses them.
  auto data = sa::gen::reversed(32);
  sa::bench::counters c;
  sa::bubble_sort(data, sa::less{}, sa::bench::count_into(c));
  CHECK(c.compare > 0 && c.swap > 0);

  auto base = sa::gen::random(200, 7);
  auto r = sa::bench::time_it([&] {
    auto v = base;
    sa::insertion_sort(v);
    sa::bench::do_not_optimize(v);
  }, 3, 1);
  CHECK(r.runs == 3);

  if(failures == 0) std::printf("sa module smoke test: OK\n");
  return failures == 0 ? 0 : 1;
}
