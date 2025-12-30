import Euclid_AlgorithmE;
import std;

//namespace Algorithm_E_Euclid {
export  template<typename T>
    requires std::integral<T>
  T GCD(T a, T b) {
    return b == 0 ? a : GCD(b, a % b);
  }
//}