pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SortStudio
import UiKit

// Playback transport for the Visualizer: to-start / step-back / play-pause /
// step-forward / to-end, a speed slider, a seek slider over the step timeline, and
// live comparison / swap / step counters. Drives the VisualizerController + the
// shared playback Timer (`player`) owned by Main. Uses UiKit controls for a
// consistent look with Graph Algorithm Studio.
Rectangle {
    id: runbar
    property var win
    property var ctl
    property var player

    implicitHeight: 92
    color: Theme.panelBg
    border.color: Theme.panelBorder
    radius: 8

    function transport(action) {
        runbar.player.running = false;
        action();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            UiButton { implicitWidth: 44; text: "⏮"; onClicked: runbar.transport(() => runbar.ctl.toStart()) }
            UiButton { implicitWidth: 44; text: "◀"; onClicked: runbar.transport(() => runbar.ctl.stepBack()) }
            UiButton {
                implicitWidth: 56
                text: runbar.player.running ? "⏸" : "▶"
                highlighted: true
                enabled: runbar.ctl.stepCount > 0
                onClicked: {
                    if (runbar.player.running) { runbar.player.running = false; return; }
                    if (runbar.ctl.atEnd) runbar.ctl.toStart();   // replay from the top
                    runbar.player.running = true;
                }
            }
            UiButton { implicitWidth: 44; text: "▶|"; onClicked: runbar.transport(() => runbar.ctl.stepForward()) }
            UiButton { implicitWidth: 44; text: "⏭"; onClicked: runbar.transport(() => runbar.ctl.toEnd()) }

            Item { Layout.preferredWidth: 12 }

            Label { text: "Speed"; color: Theme.textMuted; font.pixelSize: 12 }
            Slider {
                Layout.preferredWidth: 140
                from: 1; to: 60; stepSize: 1
                value: runbar.win.playSpeed
                onMoved: runbar.win.playSpeed = value
            }

            Item { Layout.fillWidth: true }

            StatChip { caption: "Comparisons"; value: "" + runbar.ctl.comparisons }
            StatChip { caption: "Swaps/Writes"; value: runbar.ctl.swaps + " / " + runbar.ctl.writes }
            StatChip { caption: "Step"; value: (runbar.ctl.cursor + 1) + " / " + runbar.ctl.stepCount }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Label {
                text: runbar.ctl.atEnd && runbar.ctl.stepCount > 0 ? "Sorted ✓"
                      : (runbar.ctl.note.length ? runbar.ctl.note : "Ready")
                color: runbar.ctl.atEnd && runbar.ctl.stepCount > 0 ? Theme.barSorted : Theme.textMuted
                font.pixelSize: 12
                Layout.preferredWidth: 90
            }
            Slider {
                id: seek
                Layout.fillWidth: true
                from: 0; to: Math.max(1, runbar.ctl.stepCount)
                value: runbar.ctl.cursor + 1
                onMoved: runbar.transport(() => runbar.ctl.seek(Math.round(value) - 1))
            }
        }
    }
}
