// Greatest Common Divisor (GCD) using Euclid's Algorithm (Version E)
export module Euclid_AlgorithmE;
import std;

namespace Euclid_AlgorithmE {
  export template <typename T>
    //concept PositiveIntegral = std::integral<T>; // && (T() > 0);
    concept PositiveIntegral = std::integral<T>
    && requires(T a) { a > 0 == true; };

  export template<typename T>
    requires PositiveIntegral<T>
  T GCD(T a, T b) {
    return b == 0 ? a : GCD(b, a % b);
  };

  export template<typename T>
    concept NaturalNumber = std::integral<T> && (T {1} > T {0});

  export template<typename T>
    requires NaturalNumber<T>
  T gcd(T a, T b) {
    return b == 0 ? a : gcd(b, a % b);
  }
} // namespace Euclid_AlgorithmE