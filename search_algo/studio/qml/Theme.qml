pragma Singleton
import QtQuick
import UiKit

// App theme. GENERIC colours are delegated to the shared UiKit.UiPalette (driven by the
// app's themeName binding in Main); SEARCH-specific colours (bar playback states) stay
// here. Keeping this `Theme` singleton as the app's single access point means all
// Theme.* references across the QML are unchanged if tokens move.
QtObject {
    readonly property bool dark: UiPalette.dark

    // --- generic tokens (shared UI module) ---
    readonly property color windowBg:     UiPalette.windowBg
    readonly property color panelBg:       UiPalette.panelBg
    readonly property color panelBorder:   UiPalette.panelBorder
    readonly property color canvasBg:      UiPalette.canvasBg
    readonly property color textPrimary:   UiPalette.textPrimary
    readonly property color textMuted:     UiPalette.textMuted
    readonly property color button:        UiPalette.button
    readonly property color buttonHover:   UiPalette.buttonHover
    readonly property color accent:        UiPalette.accent
    readonly property color danger:        UiPalette.danger

    // --- search-specific colours (stay in the app) ---
    // Bar playback states, kept in step with BarModel::State (C++) and the view's
    // Theme.barColor() mapping: idle / in-window / probe / eliminated / found.
    readonly property color barIdle:       dark ? "#64748b" : "#94a3b8"   // untouched
    readonly property color barWindow:     UiPrimitives.brightBlue400     // still a candidate (inside lo..hi)
    readonly property color barProbe:      UiPrimitives.yellow500         // compared against the target this step
    readonly property color barEliminated: dark ? "#334155" : "#dbe2ea"   // discarded from the search
    readonly property color barFound:      UiPrimitives.green500          // the located target

    function barColor(state) {
        switch (state) {
            case 1: return barWindow;
            case 2: return barProbe;
            case 3: return barEliminated;
            case 4: return barFound;
            default: return barIdle;
        }
    }
}
