pragma Singleton
import QtQuick
import UiKit

// App theme. GENERIC colours are delegated to the shared UiKit.UiPalette (driven by
// the app's themeName binding in Main); SORT-specific colours (bar playback states)
// stay here. Keeping this `Theme` singleton as the app's single access point means
// all Theme.* references across the QML are unchanged if tokens move.
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

    // --- sort-specific colours (stay in the app) ---
    // Bar playback states, kept in step with BarModel::State (C++) and the view's
    // stateColor() mapping.
    readonly property color barIdle:       dark ? "#64748b" : "#94a3b8"   // not being touched
    readonly property color barCompare:    UiPrimitives.yellow500         // under comparison this step
    readonly property color barSwap:       UiPrimitives.red500            // being swapped / written
    readonly property color barCursor:     UiPrimitives.brightBlue400     // the held key / min pointer
    readonly property color barSorted:     UiPrimitives.green500          // in final position

    function barColor(state) {
        switch (state) {
            case 1: return barCompare;
            case 2: return barSwap;
            case 3: return barCursor;
            case 4: return barSorted;
            default: return barIdle;
        }
    }
}
