export module Euclid_AlgorithmE;
import std;
// Greatest Common Divisor (GCD) using Euclid's Algorithm (Version E)

export template<typename T>
  requires std::integral<T>
T GCD(T a, T b) {
  return b == 0 ? a : GCD(b, a % b);
}
