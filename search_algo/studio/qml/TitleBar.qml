pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SearchStudio
import UiKit

// Single integrated title bar for the frameless window: app icon + title, the version
// between dimmed separators, a Home button (off the landing page), the theme picker,
// and the minimise / maximise / close buttons. The window owns the behaviour and wires
// it through the signals below.
Rectangle {
    id: bar
    height: 42
    color: _defs.background

    property string title: ""
    property string version: ""
    property string page: "home"
    property string themeName: ""
    property var themeNames: []
    property bool maximized: false

    signal moveRequested()
    signal maximizeToggled()
    signal minimizeRequested()
    signal closeRequested()
    signal homeRequested()
    signal themeSelected(string name)

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
            source: "qrc:/qt/qml/SearchStudio/search_logo.svg"
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

        Item {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.fillHeight: true
            Layout.preferredWidth: midRow.implicitWidth
            clip: true
            RowLayout {
                id: midRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

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
                    visible: bar.page !== "home"
                    text: "Home"
                    Layout.preferredWidth: 92
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: bar.homeRequested()
                    ToolTip.visible: hovered
                    ToolTip.text: "Back to the Studio home"
                }
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

        Item { Layout.preferredWidth: 12 }
        WinBtn { text: "—"; onClicked: bar.minimizeRequested() }
        WinBtn { text: bar.maximized ? "❐" : "☐"; onClicked: bar.maximizeToggled() }
        WinBtn { text: "✕"; hoverColor: "#e81123"; hoverTextColor: "white"; onClicked: bar.closeRequested() }
    }

    QtObject {
        id: _defs
        readonly property bool dark: Theme.dark
        readonly property color background:   dark ? "#1e293b" : Theme.panelBg
        readonly property color bottomBorder: dark ? "transparent" : "#e2e8f0"
        readonly property color titleColor:   dark ? "white" : "#0f172a"
        readonly property color versionColor: dark ? "#94a3b8" : "#64748b"
        readonly property color labelColor:   dark ? "#e2e8f0" : "#1e293b"
        readonly property color separator:    dark ? "#475569" : "#cbd5e1"
        readonly property color winbtnText:   dark ? "white" : "#1e293b"
        readonly property color winbtnHover:  dark ? "#334155" : "#e2e8f0"
    }
}
