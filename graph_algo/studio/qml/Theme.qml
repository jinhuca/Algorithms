pragma Singleton
import QtQuick
import UiKit

// App theme. GENERIC colours are delegated to the shared UiKit.Palette (driven by
// UiPalette.dark, which Main binds to the dark-mode flag); GRAPH-specific colours
// (nodes / edges / labels / algorithm-state) stay here. Keeping this `Theme`
// singleton as the app's single access point means the ~176 existing Theme.*
// references across the QML are unchanged.
QtObject {
    readonly property bool dark: UiPalette.dark

    // --- generic tokens (shared UI module) ---
    readonly property color windowBg:    UiPalette.windowBg
    readonly property color panelBg:      UiPalette.panelBg
    readonly property color panelBorder:  UiPalette.panelBorder
    readonly property color textPrimary:  UiPalette.textPrimary
    readonly property color textMuted:    UiPalette.textMuted
    readonly property color canvasBg:     UiPalette.canvasBg
    readonly property color button:       UiPalette.button
    readonly property color accent:       UiPalette.accent

    // --- graph-specific colours (stay in the app) ---
    readonly property color nodeFill:     dark ? "#1e293b" : "#dbeafe"
    readonly property color nodeBorder:   dark ? "#3b82f6" : "#2563eb"
    readonly property color nodeText:     dark ? "#e2e8f0" : "#1e3a8a"
    readonly property color edge:         dark ? "#94a3b8" : "#64748b"
    readonly property color labelBg:      dark ? "#ee1e293b" : "#f2ffffff"   // #AARRGGBB opaque chip
    readonly property color labelBorder:  dark ? "#334155" : "#e2e8f0"
    readonly property color labelText:    dark ? "#cbd5e1" : "#475569"

    // Algorithm playback state colours — mapped to the shared Figma primitive ramps
    // (UiPrimitives). stPath has no primitive match (pink) so it stays custom.
    readonly property color stFrontier:   UiPrimitives.brightBlue400   // discovered / in the frontier
    readonly property color stCurrent:    UiPrimitives.yellow500       // currently being processed
    readonly property color stSettled:    UiPrimitives.green500        // finished / settled
    readonly property color stTreeEdge:   UiPrimitives.green500        // edge kept in the result tree
    readonly property color stActiveEdge: UiPrimitives.yellow500       // edge under consideration this step
    readonly property color stPath:       "#ec4899"                    // highlighted path (no primitive pink)
    readonly property color stSource:     UiPrimitives.red500          // start / source vertex marker
}
