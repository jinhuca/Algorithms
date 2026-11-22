pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SearchStudio

// Visualizer workspace: a resizable control panel on the left (drag the separator), the
// array canvas with a target banner in the middle, the playback run bar docked below,
// and a synced pseudocode panel on the right.
Item {
    id: page
    property var win
    property var ctl
    property var player

    SplitView {
        anchors.fill: parent
        orientation: Qt.Horizontal

        handle: Rectangle {
            id: hHandle
            implicitWidth: 14; implicitHeight: 14
            color: "transparent"
            readonly property bool active: SplitHandle.hovered || SplitHandle.pressed
            readonly property bool held: SplitHandle.pressed
            Rectangle {
                anchors.centerIn: parent
                width: 2; height: 30; radius: 1
                color: hHandle.held ? Theme.accent : (hHandle.active ? Theme.panelBorder : "transparent")
            }
        }

        ControlPanel {
            SplitView.preferredWidth: 280
            SplitView.minimumWidth: 240
            win: page.win
            ctl: page.ctl
        }

        ColumnLayout {
            SplitView.fillWidth: true
            SplitView.minimumWidth: 320
            spacing: 12

            // Target + result banner.
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 40
                radius: 8
                color: Theme.panelBg
                border.color: Theme.panelBorder
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14; anchors.rightMargin: 14
                    spacing: 16
                    Label {
                        text: page.ctl.algorithm + " search"
                        color: Theme.textPrimary; font.pixelSize: 14; font.bold: true
                    }
                    Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 20; color: Theme.panelBorder }
                    Label {
                        text: "target = " + Number(page.ctl.target).toFixed(2)
                        color: Theme.textPrimary; font.pixelSize: 13
                    }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: page.ctl.finished ? page.ctl.result : "n = " + page.ctl.size
                        color: page.ctl.finished
                               ? (page.ctl.foundIndex >= 0 ? Theme.barFound : Theme.danger)
                               : Theme.textMuted
                        font.pixelSize: 13; font.bold: page.ctl.finished
                    }
                }
            }

            Frame {
                Layout.fillWidth: true
                Layout.fillHeight: true
                padding: 12
                background: Rectangle { color: Theme.canvasBg; border.color: Theme.panelBorder; radius: 8 }

                ArrayView {
                    anchors.fill: parent
                    model: page.ctl.bars
                    maxValue: page.ctl.bars.maxValue
                    showValues: page.win.showValues
                }
            }

            RunBar {
                Layout.fillWidth: true
                win: page.win
                ctl: page.ctl
                player: page.player
            }
        }

        Pseudocode {
            SplitView.preferredWidth: 280
            SplitView.minimumWidth: 220
            visible: page.win.showPseudocode
            ctl: page.ctl
        }
    }
}
