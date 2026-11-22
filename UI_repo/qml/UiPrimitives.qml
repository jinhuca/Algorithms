pragma Singleton
import QtQuick

// Primitive colour ramps — the single source of truth for raw colours, imported
// from the Figma Foundations page (import/Foundations/Color_Primitives.svg).
// These are app-agnostic; semantic tokens (UiPalette) and apps reference these by
// name (e.g. UiPrimitives.brandBlue500). Each ramp runs 25 (lightest) → 950.
// NOTE: domain-specific colours from that page (Splines / CA-line / component)
// are NOT here — they belong to the consuming app, not the shared kit.
QtObject {
    readonly property color white: "#FFFFFF"
    readonly property color black: "#000000"

    // Brand blue
    readonly property color brandBlue25:  "#EDF2FA"
    readonly property color brandBlue50:  "#CEDBED"
    readonly property color brandBlue100: "#A5BFE5"
    readonly property color brandBlue200: "#799ED2"
    readonly property color brandBlue300: "#4B78B9"
    readonly property color brandBlue400: "#375F9A"
    readonly property color brandBlue500: "#2D4B77"
    readonly property color brandBlue600: "#264066"
    readonly property color brandBlue700: "#203554"
    readonly property color brandBlue800: "#132541"
    readonly property color brandBlue900: "#0A1930"
    readonly property color brandBlue950: "#030E1F"

    // Bright blue
    readonly property color brightBlue25:  "#E5F0FF"
    readonly property color brightBlue50:  "#D6E7FF"
    readonly property color brightBlue100: "#B2D2FF"
    readonly property color brightBlue200: "#8EBCFF"
    readonly property color brightBlue300: "#6AA3FB"
    readonly property color brightBlue400: "#4789EB"
    readonly property color brightBlue500: "#2E71D3"
    readonly property color brightBlue600: "#2459A8"
    readonly property color brightBlue700: "#134186"
    readonly property color brightBlue800: "#012965"
    readonly property color brightBlue900: "#011D47"
    readonly property color brightBlue950: "#000E24"

    // Gray blue
    readonly property color grayBlue25:  "#D9E5F2"
    readonly property color grayBlue50:  "#B7CDE6"
    readonly property color grayBlue100: "#94B5DA"
    readonly property color grayBlue200: "#729DCF"
    readonly property color grayBlue300: "#5281B6"
    readonly property color grayBlue400: "#3F6897"
    readonly property color grayBlue500: "#385C85"
    readonly property color grayBlue600: "#304F73"
    readonly property color grayBlue700: "#244160"
    readonly property color grayBlue800: "#1C334D"
    readonly property color grayBlue900: "#14263A"
    readonly property color grayBlue950: "#0D1926"

    // Gray
    readonly property color gray25:  "#F9FAFB"
    readonly property color gray50:  "#F1F2F4"
    readonly property color gray100: "#E2E4E9"
    readonly property color gray200: "#CED3D9"
    readonly property color gray300: "#B3B8C1"
    readonly property color gray400: "#989EAB"
    readonly property color gray500: "#7B8493"
    readonly property color gray600: "#636B79"
    readonly property color gray700: "#4C535D"
    readonly property color gray800: "#353941"
    readonly property color gray900: "#25282D"
    readonly property color gray950: "#17191C"

    // Green
    readonly property color green25:  "#F5FBF4"
    readonly property color green50:  "#EBF8E8"
    readonly property color green100: "#D6F1D1"
    readonly property color green200: "#AEE2A3"
    readonly property color green300: "#85D475"
    readonly property color green400: "#5DC548"
    readonly property color green500: "#34B71A"
    readonly property color green600: "#2A9215"
    readonly property color green700: "#1F6E0F"
    readonly property color green800: "#15490A"
    readonly property color green900: "#0A2505"
    readonly property color green950: "#051203"

    // Yellow
    readonly property color yellow25:  "#FEF7EB"
    readonly property color yellow50:  "#FEF0D7"
    readonly property color yellow100: "#FDE4B9"
    readonly property color yellow200: "#FCD592"
    readonly property color yellow300: "#FBC260"
    readonly property color yellow400: "#FFB433"
    readonly property color yellow500: "#FFA100"
    readonly property color yellow600: "#DA8E0B"
    readonly property color yellow700: "#AA6E09"
    readonly property color yellow800: "#6C4B13"
    readonly property color yellow900: "#392B13"
    readonly property color yellow950: "#261D0D"

    // Bright yellow
    readonly property color brightYellow25:  "#FFFDF6"
    readonly property color brightYellow50:  "#FFFAED"
    readonly property color brightYellow100: "#FFF5DA"
    readonly property color brightYellow200: "#FFEBB6"
    readonly property color brightYellow300: "#FFE291"
    readonly property color brightYellow400: "#FFD86D"
    readonly property color brightYellow500: "#FFCE48"
    readonly property color brightYellow600: "#CCA53A"
    readonly property color brightYellow700: "#997C2B"
    readonly property color brightYellow800: "#66521D"
    readonly property color brightYellow900: "#33290E"
    readonly property color brightYellow950: "#0D0A04"

    // Orange
    readonly property color orange25:  "#FFF7F5"
    readonly property color orange50:  "#FFEFEB"
    readonly property color orange100: "#FFDFD7"
    readonly property color orange200: "#FFBFAF"
    readonly property color orange300: "#FF9F88"
    readonly property color orange400: "#FF8060"
    readonly property color orange500: "#FF6038"
    readonly property color orange600: "#CC4D2D"
    readonly property color orange700: "#993922"
    readonly property color orange800: "#662616"
    readonly property color orange900: "#33130B"
    readonly property color orange950: "#1A0A06"

    // Red
    readonly property color red25:  "#FFF2F4"
    readonly property color red50:  "#FFD9DF"
    readonly property color red100: "#FFB4BF"
    readonly property color red200: "#FF8798"
    readonly property color red300: "#FF687F"
    readonly property color red400: "#FF3654"
    readonly property color red500: "#FF0429"
    readonly property color red600: "#CC0321"
    readonly property color red700: "#990219"
    readonly property color red800: "#7A0214"
    readonly property color red900: "#4D010C"
    readonly property color red950: "#0D0002"

    // Color-mix — precomputed two-colour blends from the Figma Color_Mix frame.
    // Used where transparency isn't ideal: subtle field backgrounds / shade
    // variations for proper contrast. Named by their primary source + role.
    readonly property color mixBrandBlue900_950: "#061328"   // Brand blue 900 + 950 (50%)
    readonly property color mixBrandBlue700_800: "#1B2F4E"   // Brand blue 700 + 800 (35%)
    readonly property color mixBrandBlue500_400: "#315385"   // Brand blue 500 + 400 (40%)
    readonly property color mixBrandBlue600_grayBlue600: "#284469"  // Brand blue 600 + Gray blue 600 (25%)
    readonly property color mixBrandBlue700_gray500:     "#3F5476"  // Brand blue 700 + Gray 500 (42%)
    readonly property color mixBrandBlue600_gray300:     "#36527D"  // Brand blue 600 + Gray 300 (17%)
    readonly property color mixGrayBlue300_gray600:      "#5777A1"  // Gray blue 300 + Gray 600 (35%)
}
