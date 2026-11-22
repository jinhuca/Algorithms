#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of trace.ixx (the C++20 module), produced by
// scripts/gen_ga_hpp.py. The .ixx is the source of truth: edit it and re-run
//   py -I scripts/gen_ga_hpp.py
// This header lets the Qt/MinGW visualizer and the tests use the ga core
// without C++20 modules / `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "ga core requires a C++20 compiler (GCC >= 11)."
#endif

// ga::trace — the instrumentation hook that connects algorithms to a visualizer.
//
// Every algorithm takes an optional `tracer` callback and emits a `step` at each
// interesting moment (discovering a vertex, relaxing an edge, finishing, ...).
// With no tracer the algorithm is a plain, fast computation; with one, a UI (or
// a test) can observe the run and animate it step by step. This mirrors the
// subscribe() hook in fsm_cpp — one mechanism, two uses.
//
// `step` is intentionally weight-agnostic (it carries plain vertex ids and a
// double `value`) so a single tracer type works for every algorithm.

#include <functional>
#include <string>

#include "graph.hpp"

namespace ga {

  enum class evt {
    discover_vertex,   // vertex first reached / enqueued (becomes "frontier")
    visit_vertex,      // vertex taken off the frontier / now "current"
    finish_vertex,     // done processing the vertex ("settled")
    examine_edge,      // edge is being considered
    tree_edge,         // edge accepted into the result tree (BFS/DFS/MST/shortest-path)
    relax_edge,        // edge gave a shorter distance (value = new distance)
    skip_edge,         // edge considered but not used
    found_target,      // goal vertex reached
    message            // free-form note (value / note carry detail)
  };

  struct step {
    evt kind;
    vertex u = nil;        // the vertex, or an edge's source
    vertex v = nil;        // an edge's target (for *_edge events)
    double value = 0;      // e.g. the new distance on relax_edge
    std::string note{};    // optional human-readable detail
  };

  using tracer = std::function<void(const step&)>;

  // Default no-op tracer, so algorithms can call the tracer unconditionally.
  inline void ignore(const step&) {}

}  // namespace ga
