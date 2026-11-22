pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import GraphVis
import UiKit

// 2D appearance controls for the panel's "Style" tab (ported from
// fsm_visualizer/qml/Controls2D.qml, adapted to graph_algo's model). `gv` is the
// GraphView2D instance and `win` the app window, both supplied by Main. Colour
// editing is routed up via colorRequested(role) → Main opens the ColorDialog.
ColumnLayout {
    id: c
    property var gv
    property var win
    signal colorRequested(string role)
    spacing: 12

    component Section: ColumnLayout {
        id: sec
        property string title: ""
        Layout.fillWidth: true
        spacing: 6
        Label { text: sec.title; color: Theme.textPrimary; font.bold: true; font.pixelSize: 12 }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.panelBorder }
    }
    component TBtn: UiButton {
        implicitHeight: 30
        property bool square: false
        implicitWidth: square ? 34 : implicitContentWidth + leftPadding + rightPadding
        font.pixelSize: square ? 15 : 12
    }
    // Colour swatch: single-click paints the working colour onto its role, a
    // double-click opens the picker (a double-click also fires one `clicked`, so a
    // short timer arbitrates).
    component Swatch: Column {
        id: sw
        property color swatch: "#000000"
        property bool ring: false
        property string label: ""
        property string role: ""
        spacing: 3
        Timer { id: swT; interval: 250; onTriggered: c.gv.paintRole(sw.role) }
        Rectangle {
            width: 18; height: 18; radius: sw.ring ? 9 : 4
            anchors.horizontalCenter: parent.horizontalCenter
            color: sw.ring ? "transparent" : sw.swatch
            border.color: sw.ring ? sw.swatch : Theme.panelBorder
            border.width: sw.ring ? 2 : 1
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: swT.restart()
                onDoubleClicked: { swT.stop(); c.colorRequested(sw.role) }
            }
        }
        Label { text: sw.label; color: Theme.textMuted; font.pixelSize: 9
                anchors.horizontalCenter: parent.horizontalCenter }
    }

    // ---- Colours ----
    Section { title: "Colours" }
    Flow {
        Layout.fillWidth: true; spacing: 12
        Swatch { ring: true; swatch: c.gv ? c.gv.srcEff : "#000"; label: "source"; role: "source" }
        Swatch { swatch: c.gv ? c.gv.frontierEff : "#000"; label: "frontier"; role: "frontier" }
        Swatch { swatch: c.gv ? c.gv.currentEff : "#000"; label: "current"; role: "current" }
        Swatch { swatch: c.gv ? c.gv.settledEff : "#000"; label: "settled"; role: "settled" }
        Swatch { swatch: c.gv ? c.gv.nodeFillEff : "#000"; label: "node"; role: "node" }
        Swatch { swatch: c.gv ? c.gv.edgeEff : "#000"; label: "edge"; role: "edge" }
        Swatch { swatch: c.gv ? c.gv.labelEff : "#000"; label: "label"; role: "label" }
        Swatch { swatch: c.gv ? c.gv.tokenEff : "#000"; label: "indicator"; role: "token" }
    }
    RowLayout {
        Layout.fillWidth: true; spacing: 8
        Label { text: "paint:"; color: Theme.textMuted; font.pixelSize: 12 }
        Rectangle {
            width: 18; height: 18; radius: 4
            color: c.gv ? c.gv.workingColor : "#000"; border.color: Theme.textMuted; border.width: 1
            MouseArea { id: wc; anchors.fill: parent; hoverEnabled: true }
            ToolTip.visible: wc.containsMouse; ToolTip.delay: 400
            ToolTip.text: "Working colour · single-click a swatch to paint it; double-click a swatch to change it"
        }
        Item { Layout.fillWidth: true }
        TBtn { text: "Reset colours"; onClicked: c.gv.resetColors() }
    }

    // ---- Selection — click / Shift+click / box-select on the canvas ----
    Section { title: "Selection"; visible: c.gv && (c.gv.selected >= 0 || (c.gv.selRev, c.gv.edgeSelCount()) > 0) }
    Label {
        Layout.fillWidth: true
        visible: c.gv && (c.gv.selRev, c.gv.edgeSelCount()) > 0
        text: (c.gv ? c.gv.edgeSelCount() : 0) + " edge" + ((c.gv && c.gv.edgeSelCount() === 1) ? "" : "s") + " selected"
        color: Theme.textMuted; font.pixelSize: 12
    }
    RowLayout {
        Layout.fillWidth: true; spacing: 8
        visible: c.gv && c.gv.selected >= 0
        Label {
            Layout.fillWidth: true; elide: Text.ElideRight
            text: (c.gv ? (c.gv.selRev, c.gv.selCount()) : 0) > 1
                  ? (c.gv.selCount() + " nodes selected")
                  : "node: " + (c.gv && c.gv.nodeList[c.gv.selected] ? c.gv.nodeList[c.gv.selected].label : "")
            color: Theme.textPrimary; font.pixelSize: 12; font.bold: true
        }
        Rectangle {
            width: 20; height: 20; radius: 4
            color: c.gv ? (c.gv.styleRev, c.gv.selectedNodeColor()) : "#000"
            border.color: Theme.panelBorder; border.width: 1
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: c.colorRequested("nodesel") }
        }
        TBtn { text: "Reset"; onClicked: c.gv.clearSelectedColor() }
    }
    // Curve the selected edge(s): a per-edge bend that overrides the auto routing.
    RowLayout {
        Layout.fillWidth: true; spacing: 8
        visible: c.gv && (c.gv.selRev, c.gv.edgeSelCount()) > 0
        Label { text: "Curve"; color: Theme.textMuted; font.pixelSize: 12; Layout.preferredWidth: 54 }
        Slider {
            Layout.fillWidth: true; from: -200; to: 200
            value: c.gv ? (c.gv.selRev, c.gv.selectedEdgeCurve()) : 0
            onMoved: if (c.gv) c.gv.setSelectedEdgeCurve(value)
        }
        TBtn { text: "0"; onClicked: if (c.gv) c.gv.setSelectedEdgeCurve(0) }
    }

    // ---- Nodes ----
    Section { title: "Nodes" }
    RowLayout {
        Layout.fillWidth: true; spacing: 8
        Label { text: "Size"; color: Theme.textMuted; font.pixelSize: 12; Layout.preferredWidth: 54 }
        Slider { Layout.fillWidth: true; from: 0.5; to: 2.0; value: c.gv ? c.gv.nodeScale : 1
                 onMoved: if (c.gv) c.gv.nodeScale = value }
    }

    // ---- Edges ----
    Section { title: "Edges" }
    RowLayout {
        Layout.fillWidth: true; spacing: 8
        UiComboBox {
            Layout.preferredWidth: 110
            model: ["Curved", "Straight"]
            currentIndex: (c.gv && c.gv.edgeStyle === "straight") ? 1 : 0
            onActivated: if (c.gv) c.gv.edgeStyle = (currentIndex === 0 ? "curved" : "straight")
        }
        Label { text: "curve"; color: Theme.textMuted; font.pixelSize: 12
                opacity: (c.gv && c.gv.edgeStyle === "curved") ? 1 : 0.4 }
        Slider { Layout.fillWidth: true; from: 0; to: 2; value: c.gv ? c.gv.curvature : 1
                 enabled: c.gv && c.gv.edgeStyle === "curved"
                 onMoved: if (c.gv) c.gv.curvature = value }
    }
    RowLayout {
        Layout.fillWidth: true; spacing: 8
        Label { text: "Width"; color: Theme.textMuted; font.pixelSize: 12; Layout.preferredWidth: 54 }
        Slider { Layout.fillWidth: true; from: 0.5; to: 2.0; value: c.gv ? c.gv.edgeWidthScale : 1
                 onMoved: if (c.gv) c.gv.edgeWidthScale = value }
    }
    RowLayout {
        Layout.fillWidth: true; spacing: 8
        Label { text: "Arrow"; color: Theme.textMuted; font.pixelSize: 12; Layout.preferredWidth: 54 }
        Slider { Layout.fillWidth: true; from: 0.3; to: 2.0; value: c.gv ? c.gv.arrowScale : 1
                 onMoved: if (c.gv) c.gv.arrowScale = value }
    }

    // ---- Labels ----
    Section { title: "Labels" }
    RowLayout {
        Layout.fillWidth: true; spacing: 8
        Label { text: "Size"; color: Theme.textMuted; font.pixelSize: 12; Layout.preferredWidth: 54 }
        Slider { Layout.fillWidth: true; from: 0.5; to: 2.0; value: c.gv ? c.gv.labelScale : 1
                 onMoved: if (c.gv) c.gv.labelScale = value }
    }

    // ---- Animation ----
    // Travelling playback indicator (speed is on the canvas run bar).
    Section { title: "Animation" }
    RowLayout {
        Layout.fillWidth: true; spacing: 6
        UiButton {
            Layout.fillWidth: true
            text: (c.gv && c.gv.animEnabled) ? "Indicator: on" : "Indicator: off"
            checkable: true; checked: c.gv ? c.gv.animEnabled : true
            onToggled: if (c.gv) c.gv.animEnabled = checked
        }
    }
    RowLayout {
        Layout.fillWidth: true; spacing: 8
        Label { text: "Style"; color: Theme.textMuted; font.pixelSize: 12; Layout.preferredWidth: 54 }
        UiComboBox {
            Layout.fillWidth: true
            model: ["Arrow", "Dot", "Comet"]
            currentIndex: c.gv ? ["chevron", "dot", "comet"].indexOf(c.gv.tokenStyle) : 0
            onActivated: if (c.gv) c.gv.tokenStyle = ["chevron", "dot", "comet"][currentIndex]
        }
    }
    RowLayout {
        Layout.fillWidth: true; spacing: 8
        Label { text: "Size"; color: Theme.textMuted; font.pixelSize: 12; Layout.preferredWidth: 54 }
        Slider { Layout.fillWidth: true; from: 0.5; to: 2.0; value: c.gv ? c.gv.tokenScale : 1
                 onMoved: if (c.gv) c.gv.tokenScale = value }
    }

    // View toggles (grid / labels / legend / fit / fill) live on the canvas overlay
    // now — see GraphView2D.qml (the edit + zoom panes).
}
