pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SortStudio

// Visualizer workspace: a resizable control panel on the left (drag the separator),
// the active canvas view (bars / dots / strip) in the middle, and the playback run
// bar docked below it. The split handle matches Graph Algorithm Studio's.
Item {
    id: page
    property var win
    property var ctl
    property var player

    // Sound: a short tone per step, pitch ∝ the current operand's value. Only sampled
    // while enabled and on this page; a no-op when there's no audio device.
    SortAudio {
        id: audio
        active: page.win.soundOn && page.win.page === "visualizer"
    }
    Connections {
        target: page.ctl
        function onCursorChanged() { if (page.win.soundOn) audio.ping(page.ctl.stepValue); }
    }

    SplitView {
        anchors.fill: parent
        orientation: Qt.Horizontal

        // Wide, invisible-until-hovered resize handle (easy to grab) — a thin bar
        // that lights up on hover and turns accent while dragging.
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
            SplitView.preferredWidth: 260
            SplitView.minimumWidth: 220
            win: page.win
            ctl: page.ctl
        }

        ColumnLayout {
            SplitView.fillWidth: true
            SplitView.minimumWidth: 320
            spacing: 12

            Frame {
                Layout.fillWidth: true
                Layout.fillHeight: true
                padding: 12
                background: Rectangle { color: Theme.canvasBg; border.color: Theme.panelBorder; radius: 8 }

                // Only the active view is instantiated; all three bind the same model.
                Loader {
                    anchors.fill: parent
                    sourceComponent: page.win.viewMode === "dots" ? dotsView
                                   : page.win.viewMode === "strip" ? stripView : barsView
                }
                Component { id: barsView
                    SortView { model: page.ctl.bars; maxValue: page.ctl.bars.maxValue
                               showValues: page.win.showValues } }
                Component { id: dotsView
                    SortViewDots { model: page.ctl.bars; maxValue: page.ctl.bars.maxValue } }
                Component { id: stripView
                    SortViewStrip { model: page.ctl.bars; maxValue: page.ctl.bars.maxValue } }
            }

            RunBar {
                Layout.fillWidth: true
                win: page.win
                ctl: page.ctl
                player: page.player
            }
        }

        // Synced pseudocode panel (right) — resizable; hidden via "Show pseudocode".
        Pseudocode {
            SplitView.preferredWidth: 260
            SplitView.minimumWidth: 200
            visible: page.win.showPseudocode
            ctl: page.ctl
        }
    }
}
