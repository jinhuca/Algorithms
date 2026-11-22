import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import GraphVis
import UiKit

// Canvas overlays for the 3D view: the rubber-band selection box, the draggable
// info pane + state legend, and the top-right view/tools pane (zoom / fit / grid
// / axes / labels / legend / full-screen / re-align). `view` is the GraphView3D
// root; the panes call back through it (and drag via Grip host: view).
Item {
    id: ov
    anchors.fill: parent
    required property var view

    // Uniform pane button (mirrors Overlay2D): a UiButton at the pane's button height.
    component PaneBtn: UiButton { implicitHeight: 28 }

    // Rubber-band selection box (screen coords) while Shift-dragging empty space.
    Rectangle {
        visible: view.band3d
        z: 80
        x: Math.min(view.bx0, view.bx1); y: Math.min(view.by0, view.by1)
        width: Math.abs(view.bx1 - view.bx0); height: Math.abs(view.by1 - view.by0)
        color: Qt.rgba(0.23, 0.51, 0.96, 0.15); border.color: "#3b82f6"; border.width: 1
    }

    // Info pane (default top-left, draggable): document name + size.
    Rectangle {
        id: info3d
        visible: view.ctl !== null
        z: 60; radius: 8; height: 40
        x: view.paneClamp(view.info3dX, 12, view.width - width)
        y: view.paneClamp(view.info3dY, 12, view.height - height)
        color: view.colPaneBg; border.color: view.colPaneBorder; border.width: 1
        width: infoRow3d.width + 16
        Row {
            id: infoRow3d
            anchors.centerIn: parent; spacing: 6
            Grip { host: view; pane: info3d; anchors.verticalCenter: parent.verticalCenter
                     onMovedTo: function (nx, ny) { view.info3dX = nx; view.info3dY = ny } }
            Text {
                id: infoText3d
                anchors.verticalCenter: parent.verticalCenter
                text: view.docLabel + "   ·   " + view.nodeCount + " vertices   ·   " + view.edgeCount + " edges"
                color: view.colLabel; font.pixelSize: 13; font.bold: true
            }
        }
    }

    // State legend, attached just below the info pane (mirrors the 2D view).
    Rectangle {
        id: legend3d
        visible: view.showLegend3d
        z: 60; radius: 8
        anchors { top: info3d.bottom; left: info3d.left; topMargin: 8 }
        color: view.colPaneBg; border.color: view.colPaneBorder; border.width: 1
        width: legendCol3d.width + 20
        height: legendCol3d.height + 12
        Column {
            id: legendCol3d
            anchors.centerIn: parent
            spacing: 5
            Row { spacing: 8
                Rectangle { width: 13; height: 13; radius: 7; color: "transparent"
                            border.color: view.srcEff; border.width: 2; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "start node (source)"; color: view.colMuted; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
            }
            Row { spacing: 8
                Rectangle { width: 13; height: 13; radius: 7; color: view.frontierEff; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "frontier (discovered)"; color: view.colMuted; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
            }
            Row { spacing: 8
                Rectangle { width: 13; height: 13; radius: 7; color: view.currentEff; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "current (visiting)"; color: view.colMuted; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
            }
            Row { spacing: 8
                Rectangle { width: 13; height: 13; radius: 7; color: view.settledEff; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "settled (finished)"; color: view.colMuted; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    // Mode banner — makes "Add edge" mode (where dragging is off) unmistakable,
    // mirroring the 2D view.
    Rectangle {
        visible: view.edgeMode
        // Sit on the next line below the top toolbar (y 12 + height 40) so the
        // banner never overlaps the control pane, still centred horizontally.
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 60 }
        z: 70
        radius: 6
        color: Qt.rgba(view.colActiveEdge.r, view.colActiveEdge.g, view.colActiveEdge.b, 0.18)
        border.color: view.colActiveEdge; border.width: 1
        implicitWidth: bannerRow3d.implicitWidth + 20
        implicitHeight: bannerRow3d.implicitHeight + 12
        Row {
            id: bannerRow3d
            anchors.centerIn: parent; spacing: 8
            Rectangle {
                width: 11; height: 11; radius: 6; color: view.colActiveEdge
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: view.colLabel; font.pixelSize: 12; font.bold: true
                text: view.pendingSrc < 0
                      ? "Add-edge mode — click a source vertex   ·   dragging is off"
                      : "Click a target vertex to connect   ·   click the source again to cancel"
            }
        }
    }

    // Selection tip — the selected node/edge's label, weight and distance, shown
    // on-canvas (top centre). Hidden in add-edge mode (the banner uses that spot).
    Rectangle {
        visible: view.selectionTip.length > 0 && !view.edgeMode
        // Next line below the top toolbar (see banner above), centred horizontally.
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 60 }
        z: 65; radius: 6
        color: view.colPaneBg; border.color: view.colSelect; border.width: 1
        implicitWidth: selTip3d.width + 20
        implicitHeight: selTip3d.height + 12
        Text {
            id: selTip3d
            anchors.centerIn: parent
            text: view.selectionTip
            color: view.colLabel; font.pixelSize: 12; font.bold: true
        }
    }

    // Top-right control pane — the 3D view & tools (zoom / fit / grid / axes /
    // labels / legend / full screen), moved here from the side panel so the canvas
    // owns its own controls and stays usable in full screen.
    Rectangle {
        id: ctlPane
        z: 60; radius: 8; height: _overlay3dDefs.paneHeight
        x: view.paneClamp(view.ctl3dX, view.width - width - 12, view.width - width)
        y: view.paneClamp(view.ctl3dY, 12, view.height - height)
        color: view.colPaneBg; border.color: view.colPaneBorder; border.width: 1
        width: ctlRow.width + 16
        Row {
            id: ctlRow
            anchors.centerIn: parent
            spacing: 4
            Grip {
                host: view; pane: ctlPane; anchors.verticalCenter: parent.verticalCenter
                onMovedTo: function (nx, ny) { view.ctl3dX = nx; view.ctl3dY = ny }
            }
            PaneBtn {
                width: _overlay3dDefs.switchButtonWidth
                text: view.locked ? "Locked" : "Lock"
                font.pixelSize: _overlay3dDefs.text_font_size
                checkable: true;
                checked: view.locked;
                highlighted: view.locked
                onToggled: view.lockToggleRequested()
                ToolTip.visible: hovered
                ToolTip.text: view.locked
                              ? "Scene locked — click to allow edits"
                              : "Lock the scene to prevent accidental edits (drag / add / delete)"
            }
            PaneBtn {
                width: _overlay3dDefs.iconButtonWidth
                text: "↶"
                font.pixelSize: _overlay3dDefs.redo_undo_font_size
                enabled: view.canUndo
                onClicked: view.undoRequested()
                ToolTip.visible: hovered
                ToolTip.text: "Undo (Ctrl+Z)"
            }
            PaneBtn {
                width: _overlay3dDefs.iconButtonWidth
                text: "↷"
                font.pixelSize: _overlay3dDefs.redo_undo_font_size
                enabled: view.canRedo
                onClicked: view.redoRequested()
                ToolTip.visible: hovered
                ToolTip.text: "Redo (Ctrl+Y)"
            }
            ToolDivider {}
            PaneBtn {
                width: _overlay3dDefs.iconButtonWidth
                text: "−"
                font.pixelSize: _overlay3dDefs.plus_minus_font_size
                onClicked: view.zoomBy3D(1.12)
                ToolTip.visible: hovered
                ToolTip.text: "Zoom out"
            }
            PaneBtn {
                width: _overlay3dDefs.iconButtonWidth
                text: "+"
                font.pixelSize: _overlay3dDefs.plus_minus_font_size
                onClicked: view.zoomBy3D(1 / 1.12)
                ToolTip.visible: hovered
                ToolTip.text: "Zoom in"
            }
            PaneBtn {
                text: "Fit"
                font.pixelSize: _overlay3dDefs.text_font_size
                width: _overlay3dDefs.textButtonWidth
                onClicked: view.fit()
                ToolTip.visible: hovered
                ToolTip.text: "Frame the whole graph"
            }
            ToolDivider {}
            PaneBtn {
                width: _overlay3dDefs.iconButtonWidth
                text: "⊕"; font.pixelSize: _overlay3dDefs.axesFontSize
                     checkable: true; checked: view.showAxes3d; onToggled: view.showAxes3d = checked
                     ToolTip.visible: hovered; ToolTip.text: "Toggle X/Y/Z axes" }
            PaneBtn {
                width: _overlay3dDefs.iconButtonWidth
                text: "▦"; font.pixelSize: _overlay3dDefs.gridFontSize
                checkable: true; checked: view.showGrid3d; onToggled: view.showGrid3d = checked
                ToolTip.visible: hovered; ToolTip.text: "Toggle floor grid" }
            PaneBtn {
                width: _overlay3dDefs.textButtonWidth
                text: "abc";
                font.pixelSize: _overlay3dDefs.text_font_size
                checkable: true;
                checked: view.showLabels;
                onToggled: view.showLabels = checked
                ToolTip.visible: hovered;
                ToolTip.text: "Toggle labels"
            }
            PaneBtn {
                width: _overlay3dDefs.textButtonWidth
                text: "◉"
                font.pixelSize: _overlay3dDefs.showHide_font_size
                checkable: true
                checked: view.showLegend3d
                onToggled: view.showLegend3d = checked
                ToolTip.visible: hovered; ToolTip.text: "Toggle state legend"
            }
            PaneBtn {
                width: _overlay3dDefs.iconButtonWidth;
                text: "↺"
                font.pixelSize: _overlay3dDefs.reset_icon_size
                onClicked: view.realign()
                ToolTip.visible: hovered;
                ToolTip.text: "Re-align the toolbars to their default positions"
            }
            PaneBtn {
                width: _overlay3dDefs.wideTextButtonWidth
                text: view.canvasFull ? "Exit full screen" : "⛶  Full screen"
                font.pixelSize: _overlay3dDefs.text_font_size
                onClicked: view.fullScreenToggleRequested()
                ToolTip.visible: hovered
                ToolTip.text: view.canvasFull ? "Leave full screen (Esc)" : "Maximise the canvas (Esc to exit)"
            }
        }
    }

    // Private constants for this overlay (pane size, button widths, glyph font sizes).
    QtObject {
        id: _overlay3dDefs
        property real paneHeight: 40
        property real textButtonWidth: 50
        property real iconButtonWidth: 40
        property real switchButtonWidth: 70
        property real wideTextButtonWidth: 120

        property real zoomFontSize: 21
        property real gridFontSize: 30
        property real axesFontSize: 40
        property real labelsFontSize: 13
        property real legendFontSize: 40

        property real zoomLabelWidth: 48

        property real plus_minus_font_size: 20
        property real reset_icon_size: 24
        property real redo_undo_font_size: 30
        property real text_font_size: 15
        property real showHide_font_size: 40
    }
}
