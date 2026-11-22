import QtQuick
import QtQuick.Controls
import GraphVis

// Canvas overlays shown during/after a load: the busy overlay (staged label +
// spinner, swallows input) and the transient green "Scene ready" badge. Sits
// above the canvas views and the run bar (z 80). Driven by win.busy /
// win.sceneReadyMsg; reads load progress from the controller and the 3D view.
Item {
    id: busyOverlay
    anchors.fill: parent
    z: 80
    required property var win
    required property var ctl
    required property var graph3d

    // Busy overlay — covers the whole load → render → ready process with an
    // accurate stage label, and swallows input so an accidental click can't reach
    // the canvas (or trigger the OS "not responding" prompt). Stages:
    //   Loading…      — file read + parse (off-thread; UI responsive)
    //   Rendering… N% — building the scene (3D edges stream in batches)
    //   Rendering…    — GPU upload / pipeline warm-up settling (render thread)
    // then it clears once the scene is interactive and the badge below takes over.
    Rectangle {
        anchors.fill: parent
        visible: busyOverlay.win.busy
        color: Qt.rgba(0, 0, 0, 0.35)
        BusyIndicator { anchors.centerIn: parent; running: busyOverlay.win.busy; width: 64; height: 64 }
        Column {
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.verticalCenter; topMargin: 42 }
            spacing: 4
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: busyOverlay.ctl.loading ? "Loading…"
                    : busyOverlay.graph3d.building ? ("Rendering…  " + Math.min(100, Math.round(
                          busyOverlay.graph3d._edgeIdx / Math.max(1, busyOverlay.graph3d.edgeCount) * 100)) + "%")
                    : "Rendering…"
                color: "#e2e8f0"; font.pixelSize: 14; font.bold: true
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: busyOverlay.ctl.nodeCount > 400
                text: "large graph — this can take a moment"
                color: "#94a3b8"; font.pixelSize: 11
            }
        }
        MouseArea { anchors.fill: parent }   // swallow input while busy
    }

    // Transient "Scene ready" cue — shown once the 3D load gate clears so the user
    // knows it's safe to orbit/edit (does not block input; fades on interaction).
    Rectangle {
        z: 1
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 56 }
        visible: opacity > 0.01
        opacity: busyOverlay.win.sceneReadyMsg ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
        radius: 16; height: 34
        implicitWidth: readyRow.width + 26
        color: Qt.rgba(Theme.stSettled.r, Theme.stSettled.g, Theme.stSettled.b, 0.18)
        border.color: Theme.stSettled; border.width: 1
        Row {
            id: readyRow
            anchors.centerIn: parent; spacing: 8
            Rectangle { width: 12; height: 12; radius: 6; color: Theme.stSettled
                        anchors.verticalCenter: parent.verticalCenter }
            Text { text: "Scene ready"; color: Theme.textPrimary; font.pixelSize: 13; font.bold: true
                   anchors.verticalCenter: parent.verticalCenter }
        }
    }
}
