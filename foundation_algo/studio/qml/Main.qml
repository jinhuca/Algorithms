import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Window
import FoundationStudio
import UiKit

// Standalone window for the Foundation studio skeleton. The umbrella app hosts the same
// FoundationRoot with its own window + title bar.
ApplicationWindow {
    id: win
    visible: true
    width: 1100; height: 720
    minimumWidth: 640; minimumHeight: 420
    title: "Foundation Algorithm Studio"
    color: UiPalette.windowBg

    property string themeName: "dark"
    Binding { target: UiPalette; property: "themeName"; value: win.themeName }

    Settings {
        property alias winWidth: win.width
        property alias winHeight: win.height
        property alias themeName: win.themeName
    }

    palette.window: UiPalette.windowBg
    palette.windowText: UiPalette.textPrimary
    palette.base: UiPalette.panelBg
    palette.text: UiPalette.textPrimary
    palette.button: UiPalette.button
    palette.buttonText: UiPalette.textPrimary
    palette.highlight: UiPalette.accent
    palette.highlightedText: "#ffffff"

    FoundationRoot { anchors.fill: parent; anchors.margins: 12 }
}
