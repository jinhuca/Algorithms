pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Algorithms
import UiKit

// Umbrella title bar: app icon + title, version, a Home button (off the landing
// page), a slot the active studio fills with its own controls, then the theme picker
// and the window min / max / close buttons. The window owns the behaviour and wires
// it through the signals below. Generic chrome only — studio-specific controls come
// from `studioControls` (a Component the active studio Root exposes; null = none).
Rectangle {
    id: bar
    height: 42
    color: _defs.background

    property string title: ""
    property string version: ""
    property bool atHome: true
    property bool canUp: false        // true inside a studio workspace (one level above = studio landing)
    property url iconSource: "qrc:/qt/qml/Algorithms/Algorithm_Icon.svg"   // left icon (active studio's, or the app's)
    property string themeName: ""
    property var themeNames: []
    property bool maximized: false
    // Controls the active studio contributes into the title bar (e.g. graph's
    // algorithm pickers). null when the studio has none.
    property Component studioControls: null
    // Global accent control (sits next to Theme, consistent for every studio).
    property color accentColor: "transparent"   // effective accent shown in the swatch
    property bool accentIsCustom: false          // ring when a custom accent overrides the theme

    signal moveRequested()
    signal maximizeToggled()
    signal minimizeRequested()
    signal closeRequested()
    signal homeRequested()
    signal upRequested()
    signal themeSelected(string name)
    signal accentPickRequested()
    signal accentResetRequested()

    MouseArea {
        anchors.fill: parent
        onPressed: bar.moveRequested()
        onDoubleClicked: bar.maximizeToggled()
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: _defs.bottomBorder
    }

    component Sep: Rectangle {
        Layout.leftMargin: 6; Layout.rightMargin: 6
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 3; Layout.preferredHeight: 20
        color: _defs.separator
    }

    component WinBtn: ToolButton {
        implicitWidth: 46; implicitHeight: 38
        property color hoverColor: _defs.winbtnHover
        property color hoverTextColor: _defs.winbtnText
        contentItem: Text {
            text: parent.text
            color: parent.hovered ? parent.hoverTextColor : _defs.winbtnText
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle { color: parent.hovered ? parent.hoverColor : "transparent" }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        spacing: 8

        Image {
            source: bar.iconSource
            Layout.preferredWidth: 24; Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignVCenter
            sourceSize.width: 48; sourceSize.height: 48
            fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true
        }
        Label {
            text: bar.title
            color: _defs.titleColor
            font.pixelSize: 18; font.bold: true
            elide: Text.ElideRight
        }

        Sep { visible: bar.version.length > 0 }
        Label {
            visible: bar.version.length > 0
            text: bar.version
            color: _defs.versionColor
            font.pixelSize: 15; font.bold: true
            Layout.alignment: Qt.AlignVCenter
        }
        Sep { visible: bar.version.length > 0 }

        UiButton {
            visible: !bar.atHome
            text: "Home"
            Layout.preferredWidth: 92
            Layout.alignment: Qt.AlignVCenter
            onClicked: bar.homeRequested()
            ToolTip.visible: hovered
            ToolTip.text: "Back to the Algorithms home"
        }
        UiButton {
            visible: bar.canUp
            text: "Up"
            Layout.preferredWidth: 72
            Layout.alignment: Qt.AlignVCenter
            onClicked: bar.upRequested()
            ToolTip.visible: hovered
            ToolTip.text: "Up one level — back to the studio's workspaces"
        }

        // Studio-contributed controls slot (clips from the right as the window narrows).
        Item {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.fillHeight: true
            clip: true
            Loader {
                id: controlsSlot
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                sourceComponent: bar.studioControls
            }
        }

        Label { text: "Theme"; color: _defs.labelColor; font.pixelSize: 15; font.bold: true }
        UiComboBox {
            Layout.preferredWidth: 110
            Layout.alignment: Qt.AlignVCenter
            model: bar.themeNames
            currentIndex: Math.max(0, bar.themeNames.indexOf(bar.themeName))
            font.capitalization: Font.Capitalize
            onActivated: bar.themeSelected(bar.themeNames[currentIndex])
            ToolTip.visible: hovered; ToolTip.text: "Application theme"
        }
        // Accent swatch — shows the effective accent; click to pick a custom one,
        // right-click to reset to the theme's preset. A ring marks a custom accent.
        Rectangle {
            Layout.preferredWidth: 22; Layout.preferredHeight: 22
            Layout.leftMargin: 4
            Layout.alignment: Qt.AlignVCenter
            radius: 4
            color: bar.accentColor
            border.width: bar.accentIsCustom ? 2 : 1
            border.color: bar.accentIsCustom ? (_defs.dark ? "#ffffff" : "#1e293b")
                                             : (_defs.dark ? "#ffffff55" : "#00000055")
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: function (m) {
                    if (m.button === Qt.RightButton) bar.accentResetRequested();
                    else bar.accentPickRequested();
                }
                ToolTip.visible: containsMouse
                ToolTip.text: "Accent colour — click to pick, right-click to reset"
            }
        }

        Item { Layout.preferredWidth: 12 }
        WinBtn { text: "—"; onClicked: bar.minimizeRequested() }
        WinBtn { text: bar.maximized ? "❐" : "☐"; onClicked: bar.maximizeToggled() }
        WinBtn { text: "✕"; hoverColor: "#e81123"; hoverTextColor: "white"; onClicked: bar.closeRequested() }
    }

    QtObject {
        id: _defs
        readonly property bool dark: UiPalette.dark
        readonly property color background:   dark ? "#1e293b" : UiPalette.panelBg
        readonly property color bottomBorder: dark ? "transparent" : "#e2e8f0"
        readonly property color titleColor:   dark ? "white" : "#0f172a"
        readonly property color versionColor: dark ? "#94a3b8" : "#64748b"
        readonly property color labelColor:   dark ? "#e2e8f0" : "#1e293b"
        readonly property color separator:    dark ? "#475569" : "#cbd5e1"
        readonly property color winbtnText:   dark ? "white" : "#1e293b"
        readonly property color winbtnHover:  dark ? "#334155" : "#e2e8f0"
    }
}
