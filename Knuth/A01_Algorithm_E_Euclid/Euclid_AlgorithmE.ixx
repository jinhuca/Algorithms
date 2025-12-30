// Greatest Common Divisor (GCD) using Euclid's Algorithm (Version E)
export module Euclid_AlgorithmE;
import std;

export template<typename T>
concept positive_integral = std::integral<T> && requires (T val) {
  { val > 0 } -> std::same_as<bool>;
};

export template<typename T>
  requires positive_integral<T>
T GCD(T a, T b) {
  return b == 0 ? a : GCD(b, a % b);
}
