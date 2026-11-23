import std;
// Module-based smoke test for the se core, built by search_algo.slnx. Unlike the
// header-based core/tests/test_core.cpp (which the MinGW/CMake build compiles against
// the generated .hpp), this one `import`s the C++20 modules directly, so it exercises
// the real module build (seq + search families as static libs via references).
import se.seq;
import se.trace;
import se.sequential_searches.linear;
import se.sorted_searches.binary;
import se.sorted_searches.fibonacci;
import se.gen;
import se.bench;

int main() {
  std::vector<double> a = se::gen::sorted(64);
  const double present = se::gen::present_target(a, 0.5);

  if(se::binary_search(a, present) == se::nil) {
    std::printf("FAIL: binary missed a present target\n");
    return 1;
  }
  if(se::fibonacci_search(a, present) == se::nil) {
    std::printf("FAIL: fibonacci missed a present target\n");
    return 1;
  }
  if(se::linear_search(a, se::gen::missing_target(a)) != se::nil) {
    std::printf("FAIL: linear found a missing target\n");
    return 1;
  }

  se::bench::counters c;
  se::binary_search(a, present, se::less{}, se::bench::count_into(c));
  std::printf("OK: module smoke test passed (binary used %zu probes)\n", c.probes());
  return 0;
}
