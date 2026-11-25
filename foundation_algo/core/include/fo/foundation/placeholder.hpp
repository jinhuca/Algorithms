#pragma once

// ============================================================================
// GENERATED FILE -- DO NOT EDIT.
// Header-only twin of placeholder.ixx (the C++20 module), produced by
//   py -I scripts/gen_hpp.py --project foundation_algo --ns fo
// The .ixx is the source of truth: edit it and re-run the generator. This header
// lets the Qt/MinGW app and the tests use the fo core without C++20 modules /
// `import std`.
// ============================================================================

#if defined(__GNUC__) && !defined(__clang__) && (__GNUC__ < 11)
#  error "fo core requires a C++20 compiler (GCC >= 11)."
#endif

#include <string_view>

namespace fo {
// The studio's display name, surfaced by the skeleton UI to prove the core links in.
inline constexpr std::string_view studio_name = "Foundation";
}  // namespace fo
