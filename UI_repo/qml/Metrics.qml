pragma Singleton
import QtQuick

// Shared dimension tokens — spacing, radii, control sizing, borders. Replace with
// Figma-exported spacing/size tokens.
QtObject {
    readonly property int spacingXSmall: 4
    readonly property int spacingSmall:  6
    readonly property int spacing:       8
    readonly property int spacingLarge:  12
    readonly property int spacingXLarge: 16

    readonly property int radius:      6
    readonly property int radiusLarge: 10

    readonly property int controlHeight:      30
    readonly property int controlHeightSmall: 28

    readonly property int borderWidth: 1

    // Elevation — drop-shadow tokens for the three Figma DropShadows levels
    // (100 = subtle lift, 400 = raised surface, 900 = modal/overlay). Each level
    // is a (blur radius, vertical offset) pair in px; apply with a MultiEffect
    // (shadowEnabled/shadowBlur/shadowVerticalOffset) or a layered drop shadow.
    readonly property real elevationBlur100: 6
    readonly property real elevationBlur400: 16
    readonly property real elevationBlur900: 32
    readonly property real elevationOffset100: 1
    readonly property real elevationOffset400: 4
    readonly property real elevationOffset900: 10
    readonly property real elevationOpacity:   0.25

    // Glow — emphasis shadow for the active/focused state (coloured, no offset).
    // Pair with UiPalette.accent for the glow colour.
    readonly property real glowBlur:    16
    readonly property real glowOpacity: 0.55
}
