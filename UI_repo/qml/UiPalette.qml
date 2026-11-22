pragma Singleton
import QtQuick
import UiKit

// Semantic colour tokens (light / dark). `dark` is the single input — the app
// binds it. Generic tokens for apps to use; domain colours stay in the app.
//
// LIGHT values are mapped onto the Figma primitive ramps (UiPrimitives, imported
// from import/Foundations/Color_Primitives.svg). DARK values are the previous
// custom set, kept until a Figma dark page is imported.
QtObject {
    // Named themes. The app sets `themeName`; `dark` is derived from the theme's
    // mode so every existing `dark ? X : Y` token keeps working unchanged. Each
    // theme also carries an `accent` (the base colour driving highlighted controls,
    // sliders and selection) and a `tint` factor that blends the accent into the
    // surfaces — so a theme is distinct from one colour, with no per-token authoring.
    property string themeName: "dark"
    readonly property var themes: ({
        "light":  { mode: "light", accent: UiPrimitives.brightBlue500, tint: 0.0 },
        "dark":   { mode: "dark",  accent: UiPrimitives.brightBlue500, tint: 0.0 },
        "breeze": { mode: "light", accent: "#3daee9",                  tint: 0.10 },
        "forest": { mode: "light", accent: UiPrimitives.green600,      tint: 0.10 },
        "amber":  { mode: "light", accent: UiPrimitives.orange500,     tint: 0.10 }
    })
    readonly property var themeNames: ["light", "dark", "breeze", "forest", "amber"]   // display order for the picker
    readonly property var _spec: themes[themeName] !== undefined ? themes[themeName] : themes["dark"]

    readonly property bool  dark:   _spec.mode === "dark"
    // User-chosen accent override (set from the app, persisted). `transparent`
    // (alpha 0) means "no override" — fall back to the theme's preset accent. The
    // override also flows into the surface tint, so a custom accent retints too.
    property color accentOverride: "transparent"
    readonly property color accent: (accentOverride.a > 0) ? accentOverride : _spec.accent
    readonly property real  _tint:  _spec.tint
    // Blend the accent over a base surface by factor f (f = 0 ⇒ base unchanged, so
    // light/dark with tint 0 compute to exactly their original values).
    function _tinted(base, f) { return Qt.tint(base, Qt.rgba(accent.r, accent.g, accent.b, f)); }

    // DARK values map to the Figma brand-blue navy ramp (matching the ComboBox
    // mock): deep navy surfaces, a lighter navy field, white-blue text. Surfaces are
    // tinted toward the theme accent (no-op when tint is 0).
    readonly property color windowBg:     _tinted(dark ? UiPrimitives.mixBrandBlue900_950 : UiPrimitives.gray50,  _tint * 0.6)
    readonly property color panelBg:      _tinted(dark ? UiPrimitives.brandBlue800        : UiPrimitives.white,   _tint)
    readonly property color panelBorder:  _tinted(dark ? UiPrimitives.brandBlue600        : UiPrimitives.gray200, _tint)
    readonly property color canvasBg:     _tinted(dark ? UiPrimitives.mixBrandBlue900_950 : UiPrimitives.white,   _tint)

    readonly property color textPrimary:  dark ? UiPrimitives.brandBlue25 : UiPrimitives.gray900
    readonly property color textMuted:    dark ? UiPrimitives.grayBlue100 : UiPrimitives.gray700

    // Controls.
    readonly property color button:       dark ? UiPrimitives.brandBlue500 : UiPrimitives.gray100
    readonly property color buttonHover:  dark ? UiPrimitives.brandBlue400 : UiPrimitives.gray200
    readonly property color buttonDown:   dark ? UiPrimitives.brandBlue600 : UiPrimitives.gray300
    readonly property color buttonText:   textPrimary
    // Disabled controls — clearly recessed + low-contrast text so the state reads.
    readonly property color buttonDisabled:       dark ? UiPrimitives.brandBlue900 : UiPrimitives.gray50
    readonly property color buttonBorderDisabled: dark ? UiPrimitives.brandBlue800 : UiPrimitives.gray200
    readonly property color textDisabled:         dark ? UiPrimitives.grayBlue700 : UiPrimitives.gray400
    // `accent` is defined above (theme-driven). accentText stays white for contrast.
    readonly property color accentText:   UiPrimitives.white
    readonly property color danger:       UiPrimitives.red500

    // Selection / highlight (menus, lists, combo-box current row).
    readonly property color selection:     dark ? UiPrimitives.grayBlue400 : UiPrimitives.brightBlue100
    readonly property color selectionText: dark ? UiPrimitives.white        : UiPrimitives.gray900

    // --- status / feedback tokens (Figma Color_Mapped: Surface / Border / Icon) ---
    // `<status>` is the vivid icon/accent colour; `<status>Surface`/`Border`/`Text`
    // form a tinted container. Light = light tint + mid border + deep text; dark
    // inverts to a deep surface + brighter text.
    readonly property color success:        UiPrimitives.green500
    readonly property color successSurface: dark ? UiPrimitives.green900 : UiPrimitives.green50
    readonly property color successBorder:  dark ? UiPrimitives.green700 : UiPrimitives.green200
    readonly property color successText:    dark ? UiPrimitives.green300 : UiPrimitives.green700

    readonly property color error:          UiPrimitives.red500
    readonly property color errorSurface:   dark ? UiPrimitives.red900 : UiPrimitives.red50
    readonly property color errorBorder:    dark ? UiPrimitives.red700 : UiPrimitives.red200
    readonly property color errorText:      dark ? UiPrimitives.red300 : UiPrimitives.red700

    readonly property color warning:        UiPrimitives.brightYellow500
    readonly property color warningSurface: dark ? UiPrimitives.yellow900     : UiPrimitives.brightYellow100
    readonly property color warningBorder:  dark ? UiPrimitives.yellow700     : UiPrimitives.brightYellow400
    readonly property color warningText:    dark ? UiPrimitives.brightYellow300 : UiPrimitives.yellow700

    readonly property color info:           UiPrimitives.brightBlue300
    readonly property color infoSurface:    dark ? UiPrimitives.brightBlue900 : UiPrimitives.brightBlue50
    readonly property color infoBorder:     dark ? UiPrimitives.brightBlue700 : UiPrimitives.brightBlue200
    readonly property color infoText:       dark ? UiPrimitives.brightBlue300 : UiPrimitives.brightBlue700

    // Fault = critical/hard error — deeper red than `error`.
    readonly property color fault:          UiPrimitives.red600
    readonly property color faultSurface:   dark ? UiPrimitives.red950 : UiPrimitives.red25
    readonly property color faultBorder:    dark ? UiPrimitives.red800 : UiPrimitives.red300
    readonly property color faultText:      dark ? UiPrimitives.red200 : UiPrimitives.red700
}
