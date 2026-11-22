pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import GraphVis
import UiKit

// 3D appearance controls for the panel's "Style" tab (ported from
// fsm_visualizer/qml/Controls3D.qml, adapted to graph_algo). `view` is the
// GraphView3D instance, `win` the window. Colour editing routes up via
// colorRequested(role) → Main opens the ColorDialog.
ColumnLayout {
    id: c
    property var view
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
    component SliderRow: RowLayout {
        id: sr
        property string label: ""
        property alias from: s.from
        property alias to: s.to
        property alias stepSize: s.stepSize
        property real value: 0
        property bool rounded: false
        signal moved(real v)
        Layout.fillWidth: true; spacing: 8
        Label { text: sr.label; color: Theme.textMuted; font.pixelSize: 12; Layout.preferredWidth: 58 }
        Slider { id: s; Layout.fillWidth: true; value: sr.value
                 onMoved: sr.moved(sr.rounded ? Math.round(value) : value) }
    }
    component Swatch: Column {
        id: sw
        property color swatch: "#000000"
        property string label: ""
        property string role: ""
        spacing: 3
        Timer { id: swT; interval: 250; onTriggered: c.view.paintRole(sw.role) }
        Rectangle {
            width: 18; height: 18; radius: 4
            anchors.horizontalCenter: parent.horizontalCenter
            color: sw.swatch; border.color: Theme.panelBorder; border.width: 1
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: swT.restart()
                onDoubleClicked: { swT.stop(); c.colorRequested(sw.role) }
            }
        }
        Label { text: sw.label; color: Theme.textMuted; font.pixelSize: 9
                anchors.horizontalCenter: parent.horizontalCenter }
    }

    // View & tools (zoom / fit / grid / axes / labels / legend) live on the canvas
    // overlay now — see GraphView3D.qml. This panel starts at Style.

    // ---- Style ----
    Section { title: "Style" }
    SliderRow { label: "Node size"; from: 0.2; to: 2.0; value: c.view ? c.view.nodeScale : 1
                onMoved: function (v) { c.view.nodeScale = v } }
    RowLayout {
        Layout.fillWidth: true; spacing: 8
        Label { text: "Edges"; color: Theme.textMuted; font.pixelSize: 12; Layout.preferredWidth: 58 }
        UiComboBox {
            Layout.fillWidth: true; model: ["Straight", "Curved"]
            currentIndex: (c.view && c.view.edge3dStyle === "curved") ? 1 : 0
            onActivated: if (c.view) c.view.edge3dStyle = currentIndex === 1 ? "curved" : "straight"
        }
    }
    SliderRow { label: "Bend"; from: 0; to: 1; value: c.view ? c.view.curvature3d : 0.25
                enabled: c.view && c.view.edge3dStyle === "curved"
                onMoved: function (v) { c.view.curvature3d = v } }
    SliderRow { label: "Edge w"; from: 0.1; to: 2.0; value: c.view ? c.view.edgeScale : 1
                onMoved: function (v) { c.view.edgeScale = v } }
    SliderRow { label: "Edge α"; from: 0.1; to: 1.0; value: c.view ? c.view.edgeOpacity : 0.55
                onMoved: function (v) { c.view.edgeOpacity = v } }
    SliderRow { label: "Arrow"; from: 0.3; to: 2.0; value: c.view ? c.view.arrowScale : 1
                onMoved: function (v) { c.view.arrowScale = v } }
    RowLayout {
        Layout.fillWidth: true; spacing: 8
        Item { Layout.fillWidth: true }
        TBtn { text: "Reset edges"; onClicked: if (c.view) c.view.resetEdges3D() }
    }
    SliderRow { label: "Node lbl"; from: 8; to: 40; stepSize: 1; rounded: true
                value: c.view ? c.view.nodeLabelSize : 18
                onMoved: function (v) { c.view.nodeLabelSize = v } }
    SliderRow { label: "Edge lbl"; from: 8; to: 36; stepSize: 1; rounded: true
                value: c.view ? c.view.edgeLabelSize : 14
                onMoved: function (v) { c.view.edgeLabelSize = v } }

    // ---- Colours ----
    Section { title: "Colours" }
    Flow {
        Layout.fillWidth: true; spacing: 12
        Swatch { swatch: c.view ? c.view.srcEff : "#000"; label: "source"; role: "source" }
        Swatch { swatch: c.view ? c.view.frontierEff : "#000"; label: "frontier"; role: "frontier" }
        Swatch { swatch: c.view ? c.view.currentEff : "#000"; label: "current"; role: "current" }
        Swatch { swatch: c.view ? c.view.settledEff : "#000"; label: "settled"; role: "settled" }
        Swatch { swatch: c.view ? c.view.nodeFillEff : "#000"; label: "node"; role: "node" }
        Swatch { swatch: c.view ? c.view.edgeEff : "#000"; label: "edge"; role: "edge" }
        Swatch { swatch: c.view ? c.view.labelEff : "#000"; label: "label"; role: "label" }
        // Edge-state colours shown after a run: traversed tree, active edge, path.
        Swatch { swatch: c.view ? c.view.treeEdgeEff : "#000"; label: "tree"; role: "treeedge" }
        Swatch { swatch: c.view ? c.view.activeEdgeEff : "#000"; label: "active"; role: "activeedge" }
        Swatch { swatch: c.view ? c.view.pathEdgeEff : "#000"; label: "path"; role: "path" }
        Swatch { swatch: c.view ? c.view.tokenEff : "#000"; label: "indicator"; role: "token" }
    }
    RowLayout {
        Layout.fillWidth: true; spacing: 8
        Label { text: "paint:"; color: Theme.textMuted; font.pixelSize: 12 }
        Rectangle {
            width: 18; height: 18; radius: 4
            color: c.view ? c.view.workingColor : "#000"; border.color: Theme.textMuted; border.width: 1
            MouseArea { id: wc; anchors.fill: parent; hoverEnabled: true }
            ToolTip.visible: wc.containsMouse; ToolTip.delay: 400
            ToolTip.text: "Working colour · single-click a swatch to paint it; double-click a swatch to change it"
        }
        Item { Layout.fillWidth: true }
        TBtn { text: "Reset colours"; onClicked: c.view.resetColors() }
    }

    // ---- Selection — click / Shift+click / Shift-drag box-select on the canvas ----
    Section { title: "Selection"; visible: c.view && (c.view.selected >= 0 || (c.view.selRev, c.view.edgeSelCount ? c.view.edgeSelCount() : 0) > 0) }
    Label {
        Layout.fillWidth: true
        visible: c.view && (c.view.selRev, c.view.edgeSelCount ? c.view.edgeSelCount() : 0) > 0
        text: (c.view ? c.view.edgeSelCount() : 0) + " edge" + ((c.view && c.view.edgeSelCount() === 1) ? "" : "s") + " selected"
        color: Theme.textMuted; font.pixelSize: 12
    }
    // Curve the selected edge(s): a per-edge bow overriding the global edge style.
    RowLayout {
        Layout.fillWidth: true; spacing: 8
        visible: c.view && (c.view.selRev, c.view.edgeSelCount ? c.view.edgeSelCount() : 0) > 0
        Label { text: "Curve"; color: Theme.textMuted; font.pixelSize: 12; Layout.preferredWidth: 58 }
        Slider {
            Layout.fillWidth: true; from: -1; to: 1
            value: c.view ? (c.view.selRev, c.view.selectedEdgeCurve()) : 0
            onMoved: if (c.view) c.view.setSelectedEdgeCurve(value)
        }
        TBtn { text: "0"; onClicked: if (c.view) c.view.setSelectedEdgeCurve(0) }
    }
    RowLayout {
        Layout.fillWidth: true; spacing: 8
        visible: c.view && c.view.selected >= 0
        Label {
            Layout.fillWidth: true; elide: Text.ElideRight
            text: (c.view ? (c.view.selRev, c.view.selCount ? c.view.selCount() : 0) : 0) > 1
                  ? (c.view.selCount() + " nodes selected")
                  : "node: " + (c.view && c.view.nodeList[c.view.selected] ? c.view.nodeList[c.view.selected].label : "")
            color: Theme.textPrimary; font.pixelSize: 12; font.bold: true
        }
        Rectangle {
            width: 20; height: 20; radius: 4
            color: c.view ? (c.view.styleRev, c.view.selectedNodeColor()) : "#000"
            border.color: Theme.panelBorder; border.width: 1
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: c.colorRequested("nodesel") }
        }
        TBtn { text: "Reset"; onClicked: c.view.clearSelectedColor() }
    }
    // Precise position of the selected node along the world X/Y/Z axes — easier
    // than dragging in 3D. Axis colours match the gizmo; the readout shows the
    // current value. (X/Z mirror into the 2D layout; Y is a 3D-only lift.)
    ColumnLayout {
        Layout.fillWidth: true; spacing: 3
        visible: c.view && c.view.selected >= 0
        Label { text: "Position (X/Y/Z)"; color: Theme.textMuted; font.pixelSize: 11 }
        RowLayout {
            Layout.fillWidth: true; spacing: 6
            Label { text: "X"; color: "#ef4444"; font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 12 }
            Slider { Layout.fillWidth: true; from: c.view ? -c.view.posRange : -400; to: c.view ? c.view.posRange : 400
                     value: c.view ? (c.view.posRev, c.view.selectedPos().x) : 0
                     onMoved: if (c.view) c.view.setSelectedAxis("x", value) }
            Label { Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight; color: Theme.textMuted; font.pixelSize: 11
                    text: c.view ? Math.round((c.view.posRev, c.view.selectedPos().x)) : "0" }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 6
            Label { text: "Y"; color: "#22c55e"; font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 12 }
            Slider { Layout.fillWidth: true; from: c.view ? -c.view.posRange : -400; to: c.view ? c.view.posRange : 400
                     value: c.view ? (c.view.posRev, c.view.selectedPos().y) : 0
                     onMoved: if (c.view) c.view.setSelectedAxis("y", value) }
            Label { Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight; color: Theme.textMuted; font.pixelSize: 11
                    text: c.view ? Math.round((c.view.posRev, c.view.selectedPos().y)) : "0" }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 6
            Label { text: "Z"; color: "#3b82f6"; font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 12 }
            Slider { Layout.fillWidth: true; from: c.view ? -c.view.posRange : -400; to: c.view ? c.view.posRange : 400
                     value: c.view ? (c.view.posRev, c.view.selectedPos().z) : 0
                     onMoved: if (c.view) c.view.setSelectedAxis("z", value) }
            Label { Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight; color: Theme.textMuted; font.pixelSize: 11
                    text: c.view ? Math.round((c.view.posRev, c.view.selectedPos().z)) : "0" }
        }
        UiButton { Layout.fillWidth: true; text: "Reset position"
                 enabled: c.view && c.view.posOverride[c.view.selected] !== undefined
                 onClicked: c.view.clearSelectedPos() }
    }

    // ---- Animation ----
    // Travelling playback indicator (speed is on the canvas run bar).
    Section { title: "Animation" }
    RowLayout {
        Layout.fillWidth: true; spacing: 6
        UiButton {
            Layout.fillWidth: true
            text: (c.view && c.view.animEnabled) ? "Indicator: on" : "Indicator: off"
            checkable: true; checked: c.view ? c.view.animEnabled : true
            onToggled: if (c.view) c.view.animEnabled = checked
        }
    }
    RowLayout {
        Layout.fillWidth: true; spacing: 8
        Label { text: "Style"; color: Theme.textMuted; font.pixelSize: 12; Layout.preferredWidth: 54 }
        UiComboBox {
            Layout.fillWidth: true
            model: ["Arrow", "Dot", "Comet"]
            currentIndex: c.view ? ["chevron", "dot", "comet"].indexOf(c.view.tokenStyle) : 0
            onActivated: if (c.view) c.view.tokenStyle = ["chevron", "dot", "comet"][currentIndex]
        }
    }
    RowLayout {
        Layout.fillWidth: true; spacing: 8
        Label { text: "Size"; color: Theme.textMuted; font.pixelSize: 12; Layout.preferredWidth: 54 }
        Slider { Layout.fillWidth: true; from: 0.5; to: 2.0; value: c.view ? c.view.tokenScale : 1
                 onMoved: if (c.view) c.view.tokenScale = value }
    }

    // ---- Help ----
    Label {
        Layout.fillWidth: true; wrapMode: Text.WordWrap
        text: "Click a node to select, drag to move it (pins it) · drag empty space to orbit · right-drag to pan · wheel or ± to zoom · toggle the X/Y/Z axes with ⊕."
        color: Theme.textMuted; font.pixelSize: 11
    }
}
