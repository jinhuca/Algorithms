#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of trace.ixx (the C++20 module), produced by
// scripts/gen_sa_hpp.py. The .ixx is the source of truth: edit it and re-run
//   py -I scripts/gen_sa_hpp.py
// This header lets the Qt/MinGW app and the tests use the sa core without
// C++20 modules / `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "sa core requires a C++20 compiler (GCC >= 11)."
#endif

// sa::trace — the instrumentation hook that connects the sort algorithms to a
// visualizer, mirroring ga::trace in the graph studio.
//
// Every algorithm takes an optional `tracer` callback and emits a `step` at each
// interesting moment (comparing two elements, swapping them, writing a value,
// marking a position final, ...). With no tracer the algorithm is a plain, fast
// sort; with one, a UI (or a test) observes the exact same run and animates it
// step by step. One mechanism, two uses.
//
// `step` is intentionally element-agnostic: it carries plain positions (indices)
// plus a double `value` used only by write events (the new element value, as a
// bar height). So a single tracer type serves every sort, and a generic sort over
// an arithmetic T fills `value`; for a non-arithmetic T it simply stays 0.

#include <algorithm>
#include <bit>
#include <chrono>
#include <cmath>
#include <compare>
#include <concepts>
#include <cstddef>
#include <cstdint>
#include <functional>
#include <iterator>
#include <limits>
#include <map>
#include <numeric>
#include <queue>
#include <random>
#include <ranges>
#include <string>
#include <tuple>
#include <type_traits>
#include <unordered_set>
#include <utility>
#include <vector>
#include "seq.hpp"

namespace sa {
  enum class evt {
    compare,        // comparing a[i] with a[j]
    swap,           // a[i] and a[j] exchanged
    overwrite,      // a[i] was written with `value` (shifts in insertion / cycle sort)
    read,           // a[i] read / probed (e.g. cycle sort counting the insertion point)
    cursor,         // a[i] is the current key / min pointer / boundary marker
    mark_sorted,    // a[i] has reached its final sorted position
    pass_boundary,  // one pass / phase completed (note carries detail)
    message         // free-form narration (value / note carry detail)
  };

  struct step {
    evt kind;
    index i = nil;         // the position, or the first of a compared/swapped pair
    index j = nil;         // the second position (for compare / swap)
    double value = 0;      // e.g. the value written on `overwrite`
    std::string note{};    // optional human-readable detail
    int line = -1;         // pseudocode line index this step maps to (-1 = none)
  };

  using tracer = std::function<void(const step&)>;

  // Default no-op tracer, so algorithms can call the tracer unconditionally.
  inline void ignore(const step&) {}

  // Project an element to the double carried by write events (a bar height for the
  // visualizer). Numeric elements map to their value; any other T contributes 0 —
  // the trace positions still drive the animation either way.
  template <typename T>
  inline double value_of(const T& x) {
    if constexpr(std::is_arithmetic_v<T>) return static_cast<double>(x);
    else return 0.0;
  }
}  // namespace sa
