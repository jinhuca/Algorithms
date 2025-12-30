#pragma once
import std;

template <typename T>
  requires std::integral<T>
T GCD(T a, T b) {
  return b == 0 ? a : GCD(b, a % b);
}
