module;

#include <string_view>

export module fo.placeholder;

export namespace fo {
// The studio's display name, surfaced by the skeleton UI to prove the core links in.
inline constexpr std::string_view studio_name = "Foundation";
}  // namespace fo
