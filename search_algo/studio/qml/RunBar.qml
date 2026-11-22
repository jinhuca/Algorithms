pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SearchStudio
import UiKit

// Playback transport for the Visualizer: to-start / step-back / play-pause /
// step-forward / to-end, a speed slider, a seek slider over the step timeline, and live
// probe / remaining / step counters. Drives the VisualizerController + the shared
// playback Timer (`player`) owned by Main.
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
                    if (runbar.ctl.atEnd) runbar.ctl.toStart();
                    runbar.player.running = true;
                }
            }
            UiButton { implicitWidth: 44; text: "▶|"; onClicked: runbar.transport(() => runbar.ctl.stepForward()) }
            UiButton { implicitWidth: 44; text: "⏭"; onClicked: runbar.transport(() => runbar.ctl.toEnd()) }

            Item { Layout.preferredWidth: 12 }

            Label { text: "Speed"; color: Theme.textMuted; font.pixelSize: 12 }
            Slider {
                Layout.preferredWidth: 140
                from: 1; to: 30; stepSize: 1
                value: runbar.win.playSpeed
                onMoved: runbar.win.playSpeed = value
            }

            Item { Layout.fillWidth: true }

            StatChip { caption: "Target"; value: Number(runbar.ctl.target).toFixed(2) }
            StatChip { caption: "Probes"; value: "" + runbar.ctl.probes }
            StatChip { caption: "In window"; value: "" + runbar.ctl.remaining }
            StatChip { caption: "Step"; value: (runbar.ctl.cursor + 1) + " / " + runbar.ctl.stepCount }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Label {
                text: runbar.ctl.finished ? runbar.ctl.result
                      : (runbar.ctl.note.length ? runbar.ctl.note : "Ready")
                color: runbar.ctl.finished
                       ? (runbar.ctl.foundIndex >= 0 ? Theme.barFound : Theme.danger)
                       : Theme.textMuted
                font.pixelSize: 12
                elide: Text.ElideRight
                Layout.preferredWidth: 320
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
