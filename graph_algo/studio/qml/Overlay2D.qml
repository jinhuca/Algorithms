import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import GraphVis
import UiKit

// Draggable canvas panes for the 2D view: the Info pane + state legend, the Edit
// pane (grid / labels / legend toggles, undo/redo/lock/full-screen), and the Zoom
// pane. `view` is the GraphView2D root; the panes call back through it (and drag
// via Grip host: view).
Item {
    id: ov
    anchors.fill: parent
    required property var view

    // Uniform pane button (matches the 2D view's btnH = 28).
    component PaneBtn: UiButton { implicitHeight: 28 }
    // Reusable vertical divider between button groups (one source of truth).
    component Sep: ToolDivider { }

    // Draggable canvas panes — Info (sample-data), Edit, Zoom — all with a grip,
    // uniform height/buttons, top-aligned by default, positions persisted.

    // Info pane: document name + size.
    Rectangle {
        id: infoPane
        z: 60; radius: 8; height: view.paneH
        color: view.paneBg; border.color: Theme.panelBorder; border.width: 1
        width: infoRow.width + 16
        x: view.paneClamp(view.infoX, 12, view.width - width)
        y: view.paneClamp(view.infoY, 12, view.height - height)
        Row {
            id: infoRow; anchors.centerIn: parent; spacing: 8
            Grip { host: view; pane: infoPane; onMovedTo: function (nx, ny) { view.infoX = nx; view.infoY = ny } }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: view.docLabel + "   ·   " + (view.ctl ? view.ctl.nodeCount : 0) + " vertices   ·   "
                      + (view.ctl ? view.ctl.edgeCount : 0) + " edges"
                color: Theme.textPrimary; font.pixelSize: 13; font.bold: true
            }
        }
    }

    // State legend, attached just below the info pane (toggle in the Edit pane).
    Rectangle {
        id: legendPane
        visible: view.showLegend
        z: 60; radius: 8
        color: view.paneBg; border.color: Theme.panelBorder; border.width: 1
        x: infoPane.x
        y: infoPane.y + infoPane.height + 8
        width: legendCol.width + 20
        height: legendCol.height + 12
        Column {
            id: legendCol
            anchors.centerIn: parent
            spacing: 5
            Row { spacing: 8
                // Ring swatch — matches the red ring drawn around the source vertex.
                Rectangle { width: 13; height: 13; radius: 7; color: "transparent"
                            border.color: Theme.stSource; border.width: 2; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "start node (source)"; color: Theme.textMuted; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
            }
            Row { spacing: 8
                Rectangle { width: 13; height: 13; radius: 7; color: Theme.stFrontier; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "frontier (discovered)"; color: Theme.textMuted; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
            }
            Row { spacing: 8
                Rectangle { width: 13; height: 13; radius: 7; color: Theme.stCurrent; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "current (visiting)"; color: Theme.textMuted; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
            }
            Row { spacing: 8
                Rectangle { width: 13; height: 13; radius: 7; color: Theme.stSettled; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "settled (finished)"; color: Theme.textMuted; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    // Edit / layout pane (the "+Edge" panel).
    Rectangle {
        id: editPane
        z: 60; radius: 8; height: view.paneH
        color: view.paneBg; border.color: Theme.panelBorder; border.width: 1
        width: editRow.width + 16
        x: view.paneClamp(view.editX, view.width - width - 12, view.width - width)
        y: view.paneClamp(view.editY, 12, view.height - height)
        Row {
            id: editRow; anchors.centerIn: parent; spacing: 4
            Grip { host: view; pane: editPane; onMovedTo: function (nx, ny) { view.editX = nx; view.editY = ny } }
            PaneBtn {
                text: view.locked ? "Locked" : "Lock"
                font.pixelSize: _overlay2dDefs.text_font_size
                width: _overlay2dDefs.switchButtonWidth
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
                width: _overlay2dDefs.iconButtonWidth
                text: "↶"
                font.pixelSize: _overlay2dDefs.redo_undo_font_size
                enabled: view.canUndo;
                onClicked: view.undoRequested()
                ToolTip.visible: hovered;
                ToolTip.text: "Undo (Ctrl+Z)"
            }
            PaneBtn {
                width: _overlay2dDefs.iconButtonWidth
                text: "↷"
                font.pixelSize: _overlay2dDefs.redo_undo_font_size
                enabled: view.canRedo
                onClicked: view.redoRequested()
                ToolTip.visible: hovered
                ToolTip.text: "Redo (Ctrl+Y)"
            }
            Sep { }
            PaneBtn {
                width: _overlay2dDefs.iconButtonWidth
                text: "−";
                font.pixelSize: _overlay2dDefs.plus_minus_font_size
                onClicked: view.zoomBy(1 / 1.2)
                ToolTip.visible: hovered
                ToolTip.text: "Zoom out"
            }
            Label {
                width: _overlay2dDefs.zoomLabelWidth
                height: view.btnH
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: Math.round(view.zoom * 100) + "%"
                font.pixelSize: _overlay2dDefs.text_font_size
                color: Theme.textPrimary
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.zoom = 1
                }
            }
            PaneBtn {
                width: _overlay2dDefs.iconButtonWidth
                text: "+"
                font.pixelSize: _overlay2dDefs.plus_minus_font_size
                onClicked: view.zoomBy(1.2)
                ToolTip.visible: hovered
                ToolTip.text: "Zoom in"
            }
            PaneBtn {
                text: "Fit";
                font.pixelSize: _overlay2dDefs.text_font_size
                width: _overlay2dDefs.textButtonWidth
                onClicked: view.fitView()
                ToolTip.visible: hovered
                ToolTip.text: "Fit graph to view"
            }
            Sep { }
            PaneBtn {
                width: _overlay2dDefs.iconButtonWidth;
                text: "▦";
                font.pixelSize: _overlay2dDefs.grid_font_size;
                checkable: true
                checked: view.showGrid
                onToggled: view.showGrid = checked
                ToolTip.visible: hovered
                ToolTip.text: "Toggle background grid"
            }
            PaneBtn {
                width: _overlay2dDefs.textButtonWidth
                text: "abc"
                font.pixelSize: _overlay2dDefs.text_font_size
                checkable: true
                checked: view.showLabels
                onToggled: view.showLabels = checked
                ToolTip.visible: hovered
                ToolTip.text: "Toggle labels"
            }
            PaneBtn {
                width: _overlay2dDefs.textButtonWidth
                text: "◉"
                font.pixelSize: _overlay2dDefs.showHide_font_size
                checkable: true
                checked: view.showLegend
                onToggled: view.showLegend = checked
                ToolTip.visible: hovered
                ToolTip.text: "Toggle state legend"
            }
            PaneBtn {
                width: _overlay2dDefs.iconButtonWidth
                text: "↺"
                font.pixelSize: _overlay2dDefs.reset_icon_size
                onClicked: view.realign()
                ToolTip.visible: hovered
                ToolTip.text: "Re-align panes to the default positions"
            }
            PaneBtn {
                width: _overlay2dDefs.wideTextButtonWidth
                text: view.canvasFull ? "Exit full screen" : "⛶  Full screen"
                font.pixelSize: _overlay2dDefs.text_font_size
                onClicked: view.fullScreenToggleRequested()
                ToolTip.visible: hovered
                ToolTip.text: view.canvasFull ? "Leave full screen (Esc)" : "Maximise the canvas (Esc to exit)"
            }
        }
    }

    // Mode banner — makes "Add edge" mode (where dragging is off) unmistakable.
    Rectangle {
        visible: view.edgeMode
        // Next line below the top toolbar (y 12 + height 40), centred horizontally,
        // so the banner clears both the control pane and the bottom RunBar.
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 60 }
        z: 70
        radius: 6
        color: Qt.rgba(Theme.stActiveEdge.r, Theme.stActiveEdge.g, Theme.stActiveEdge.b, 0.18)
        border.color: Theme.stActiveEdge; border.width: 1
        implicitWidth: bannerRow.implicitWidth + 20
        implicitHeight: bannerRow.implicitHeight + 12
        Row {
            id: bannerRow
            anchors.centerIn: parent; spacing: 8
            Rectangle {
                width: 11; height: 11; radius: 6; color: Theme.stActiveEdge
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.textPrimary; font.pixelSize: 12; font.bold: true
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
        // Next line below the top toolbar (y 12 + height 40) so the tip never
        // overlaps the control pane, still centred horizontally.
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 60 }
        z: 55; radius: 6
        color: view.paneBg; border.color: Theme.accent; border.width: 1
        implicitWidth: selTipText.width + 20
        implicitHeight: selTipText.height + 12
        Text {
            id: selTipText
            anchors.centerIn: parent
            text: view.selectionTip
            color: Theme.textPrimary; font.pixelSize: 12; font.bold: true
        }
    }

    QtObject {
        id: _overlay2dDefs;
        property real iconButtonWidth: 40
        property real textButtonWidth: 50
        property real switchButtonWidth: 70
        property real addEdgeButtonWidth: 100
        property real wideTextButtonWidth: 120

        property real zoomLabelWidth: 42

        property real redo_undo_font_size: 30
        property real plus_minus_font_size: 20
        property real grid_font_size: 32
        property real showHide_font_size: 40
        property real reset_icon_size: 24
        property real text_font_size: 15
    }
}
