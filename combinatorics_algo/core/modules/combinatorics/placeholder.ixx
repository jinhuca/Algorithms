module;

#include <string_view>

export module cb.placeholder;

export namespace cb {
// The studio's display name, surfaced by the skeleton UI to prove the core links in.
inline constexpr std::string_view studio_name = "Combinatorics";
}  // namespace cb
