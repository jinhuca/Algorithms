module;

#include <string_view>

export module nu.placeholder;

export namespace nu {
// The studio's display name, surfaced by the skeleton UI to prove the core links in.
inline constexpr std::string_view studio_name = "Numerics";
}  // namespace nu
