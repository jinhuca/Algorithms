module;

// se::trace — the instrumentation hook that connects the search algorithms to a
// visualizer, mirroring sa::trace / ga::trace.
//
// Every algorithm takes an optional `tracer` callback and emits a `step` at each
// interesting moment (probing an element, narrowing the lo/hi window, discarding a
// region, finding the target, ...). With no tracer the algorithm is a plain, fast
// search; with one, a UI (or a test) observes the exact same run and animates it step
// by step. One mechanism, two uses.
//
// `step` is intentionally element-agnostic: it carries plain positions (indices) plus
// a double `value` used only to show the probed element's height. So a single tracer
// type serves every search.

#include <functional>
#include <string>
#include <type_traits>

export module se.trace;

import se.seq;

export namespace se {

  enum class evt {
    probe,          // examining a[i] — comparing a[i] against the target
    lo_bound,       // the search window's lower bound moved to i (sorted searches)
    hi_bound,       // the search window's upper bound moved to i (sorted searches)
    mid,            // i is the current midpoint / interpolation / jump probe position
    eliminate,      // positions [i..j] were discarded from the remaining window
    found,          // target located at i
    not_found,      // the search finished without finding the target
    pass_boundary,  // one iteration / probe step completed (note carries detail)
    message         // free-form narration (value / note carry detail)
  };

  struct step {
    evt kind;
    index i = nil;        // the probed position, or the first of a discarded [i..j] range
    index j = nil;        // the second position (for eliminate ranges)
    double value = 0;     // the probed element's value (a bar height for the visualizer)
    std::string note{};   // optional human-readable detail
    int line = -1;        // pseudocode line index this step maps to (-1 = none)
  };

  using tracer = std::function<void(const step&)>;

  // Default no-op tracer, so algorithms can call the tracer unconditionally.
  inline void ignore(const step&) {}

  // Project an element to the double carried by a step (a bar height for the
  // visualizer). Numeric elements map to their value; any other T contributes 0 —
  // the trace positions still drive the animation either way.
  template <class T>
  inline double value_of(const T& x) {
    if constexpr (std::is_arithmetic_v<T>) return static_cast<double>(x);
    else return 0.0;
  }

}  // namespace se
