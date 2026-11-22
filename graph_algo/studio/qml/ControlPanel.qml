import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import GraphVis
import UiKit   // shared UI module — Data Sets buttons use UiButton (proof of adoption)

// The left control panel: one flat, scrollable column (no tabs) — Data Sets,
// Selected Data Set, Build Graph, View Mode (+ layout & cuboid/globe sliders),
// then the context-sensitive 2D/3D appearance controls (Controls2D/Controls3D).
// The window supplies itself, the controller, both graph views and the dialogs
// so the handlers don't reach across files for ids. (The view & tools — zoom /
// fit / grid / labels / legend / axes — live on the canvas overlays, not here.)
Frame {
    id: controlPane
    required property var win
    required property var ctl
    required property var graph
    required property var graph3d
    required property var dialogs

    background: Rectangle { color: Theme.panelBg; border.color: Theme.panelBorder; radius: 8 }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8
        // Scrollable so the panel's lower controls aren't clipped when the
        // window (or a short/high-DPI screen) can't fit the whole column.
        ScrollView {
            id: panelScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            // Show the scrollbar only when needed, and reserve its width so
            // it sits in its own gutter rather than overlapping the controls.
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            readonly property real vbarSpace: ScrollBar.vertical.visible ? ScrollBar.vertical.width : 0
            ColumnLayout {
                width: panelScroll.availableWidth - panelScroll.vbarSpace
                spacing: 10

                // Launch-guard notice: the last session's graph was too large to open
                // automatically without freezing the UI. Offer to open it on demand.
                Rectangle {
                    Layout.fillWidth: true; visible: win._skippedNodes > 0
                    radius: 6; color: Qt.rgba(Theme.stActiveEdge.r, Theme.stActiveEdge.g, Theme.stActiveEdge.b, 0.12)
                    border.color: Theme.stActiveEdge; border.width: 1
                    implicitHeight: skipCol.implicitHeight + 16
                    ColumnLayout {
                        id: skipCol
                        anchors.fill: parent; anchors.margins: 8; spacing: 6
                        Label {
                            Layout.fillWidth: true; wrapMode: Text.WordWrap
                            color: Theme.textPrimary; font.pixelSize: 11
                            text: "Last graph (" + win._skippedName + ", " + win._skippedNodes
                                  + " nodes) was too large to open automatically — it would freeze the UI while rendering."
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            UiButton { text: "Open anyway"; Layout.fillWidth: true
                                     onClicked: win.confirmUnsaved(function () { win.openSkipped(); })
                                     ToolTip.visible: hovered; ToolTip.text: "Load it now (the UI will pause while it renders)" }
                            UiButton { text: "Dismiss"; Layout.fillWidth: true
                                     onClicked: { win._skippedDoc = ""; win._skippedFile = "";
                                                  win._skippedName = ""; win._skippedNodes = 0; win._skippedModified = false; } }
                        }
                    }
                }

                // (Algorithm + data-set selection live in the title bar — see TitleBar.qml.)

                // ===== Build Graph — node / edge modification =====
                SectionHeader { title: "Build Graph"; expanded: win.secBuildGraph
                                onToggled: win.secBuildGraph = !win.secBuildGraph }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 10; visible: win.secBuildGraph
                    RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    UiButton {
                        text: "Add vertices"; Layout.fillWidth: true; enabled: !win.editLocked
                        onClicked: { ctl.addVertices(vcountBox.value); graph.fitView(); }
                        ToolTip.visible: hovered; ToolTip.text: "Add N blank vertices at once"
                    }
                    Label { text: "Numbers"; color: Theme.textMuted; Layout.preferredWidth: 58 }
                    SpinBox { id: vcountBox; from: 1; to: 99; value: 5; Layout.preferredWidth: 96; enabled: !win.editLocked }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    UiButton {
                        readonly property int activePending: win.use3D ? graph3d.pendingSrc : graph.pendingSrc
                        text: graph.edgeMode ? (activePending >= 0 ? "Pick target…" : "Pick source…") : "Add edge"
                        Layout.fillWidth: true; checkable: true; checked: graph.edgeMode; enabled: !win.editLocked
                        highlighted: graph.edgeMode          // accent colour while active
                        onToggled: graph.edgeMode = checked
                        ToolTip.visible: hovered
                        ToolTip.text: "Connect two vertices. While on, click a source then a target; dragging is disabled."
                    }
                    Label { text: "Weight"; color: Theme.textMuted; Layout.preferredWidth: 58 }
                    SpinBox {
                        id: weightBox
                        from: 1; to: 999; value: 1
                        Layout.preferredWidth: 96; enabled: !win.editLocked
                        onValueChanged: graph.newWeight = value
                    }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    UiButton { text: "Paste edges…"; Layout.fillWidth: true; enabled: !win.editLocked; onClicked: dialogs.openPaste()
                             ToolTip.visible: hovered; ToolTip.text: "Build a graph from a text edge list" }
                    UiButton { text: "Directed"; Layout.fillWidth: true; checkable: true; checked: ctl.directed; enabled: !win.editLocked
                             onToggled: ctl.directed = checked
                             ToolTip.visible: hovered; ToolTip.text: "Treat edges as directed" }
                }
                }   // end Build Graph body

                // ===== View Mode — 2D / 3D + auto-layout =====
                SectionHeader { title: "View Mode"; expanded: win.secViewMode
                                onToggled: win.secViewMode = !win.secViewMode }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 10; visible: win.secViewMode
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        // 2D / 3D selector — kept in sync with the title-bar switch (both
                        // drive win.use3D).
                        UiButton { text: "2D"; Layout.fillWidth: true; checkable: true; autoExclusive: true
                                 checked: !win.use3D; onClicked: win.use3D = false }
                        UiButton { text: "3D"; Layout.fillWidth: true; checkable: true; autoExclusive: true
                                 checked: win.use3D; onClicked: win.use3D = true }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        Label { text: "Layout"; color: Theme.textMuted; Layout.preferredWidth: 66 }
                        UiComboBox {
                            id: layoutBox
                            Layout.fillWidth: true
                            // Auto-arrange options (Force-directed / Circular) plus manual
                            // modes: Free-style keeps positions and lets you drag / double-
                            // click to place; the 3D view adds the Cuboid box lattice.
                            model: win.use3D ? ["Free-style", "Force-directed", "Circular", "Cuboid", "Globe"]
                                             : ["Free-style", "Force-directed", "Circular"]
                            // Reflect the actual layout: Globe / Cuboid whenever the 3D view
                            // is in that mode (incl. a restored doc), else the last flat choice.
                            // A Binding (not a plain currentIndex:) so it reasserts after the
                            // ComboBox sets currentIndex on a click.
                            Binding {
                                target: layoutBox; property: "currentIndex"
                                value: Math.max(0, layoutBox.model.indexOf(
                                           (win.use3D && graph3d.globeMode) ? "Globe"
                                         : (win.use3D && graph3d.cuboidMode) ? "Cuboid" : win.layoutKind))
                            }
                            onActivated: {
                                var choice = currentText;              // capture for the deferred closure
                                if (choice !== "Cuboid" && choice !== "Globe") win.layoutKind = choice;
                                if (choice === "Cuboid" || choice === "Globe") win.use3D = true;   // 3D-only modes

                                // The actual re-arrangement. For a large graph this blocks
                                // the GUI thread (relayout + instance rebuild), so in 3D we
                                // run it behind the same "Rendering…" gate as a file load —
                                // which also fires the "Scene ready" badge when it settles.
                                function applyLayout() {
                                    if (choice === "Cuboid") {
                                        graph3d.clearGlobe();
                                        graph3d.layoutCuboid();
                                    } else if (choice === "Globe") {
                                        // Airline-map: cities onto a sphere by lon/lat, routes arc.
                                        graph3d.clearCuboid();
                                        graph3d.layoutGlobe();
                                    } else if (choice === "Free-style") {
                                        // Manual layout: keep positions (no re-arrange, no
                                        // reframe); drag / double-click to place nodes freely.
                                        if (win.use3D) graph3d.freeStyle();
                                    } else {
                                        graph3d.clearCuboid();          // back to the flat 2D layout in 3D
                                        graph3d.clearGlobe();
                                        if (choice === "Circular") ctl.layoutCircular();
                                        else ctl.relayout();
                                        if (win.use3D) {
                                            // The flat layouts spread ~34·n units wide — fine in 2D
                                            // (zoom-to-fit), but in 3D the fixed node/grid size renders
                                            // that sub-pixel, so the scene looks empty. Scale the layout
                                            // into a bounded, node-proportionate square so the 3D camera
                                            // frames it with visible nodes, grid and axes.
                                            var side = Math.max(600, graph3d.nr * 6 * Math.sqrt(Math.max(1, ctl.nodeCount)));
                                            ctl.layoutToRegion(side, side, graph3d.nr * 2);
                                        }
                                        graph.fitView();
                                        if (win.use3D) graph3d.fit();
                                    }
                                }

                                if (win.use3D) win.beginPrepare3D(applyLayout);
                                else applyLayout();
                            }
                            ToolTip.visible: hovered
                            ToolTip.text: "Arrange the vertices — Free-style lets you place them by hand (drag / double-click); Cuboid is a 3D box"
                        }
                    }
                    // Cuboid box proportions (width : height : depth) — shown only while
                    // the cuboid layout is active. Each slider re-lays the box (the view
                    // debounces). Axis colours match the X/Y/Z gizmo.
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 3
                        visible: win.use3D && graph3d.cuboidMode
                        Label { text: "Cuboid shape  (W : H : D)"; color: Theme.textMuted; font.pixelSize: 11 }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            Label { text: "W"; color: "#ef4444"; font.bold: true; font.pixelSize: 12; Layout.preferredWidth: 14 }
                            Slider { Layout.fillWidth: true; from: 1; to: 5; stepSize: 1; snapMode: Slider.SnapAlways
                                     value: graph3d.cuboidW; onMoved: graph3d.cuboidW = value }
                            Label { Layout.preferredWidth: 14; horizontalAlignment: Text.AlignRight; color: Theme.textMuted
                                    font.pixelSize: 11; text: Math.round(graph3d.cuboidW) }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            Label { text: "H"; color: "#22c55e"; font.bold: true; font.pixelSize: 12; Layout.preferredWidth: 14 }
                            Slider { Layout.fillWidth: true; from: 1; to: 5; stepSize: 1; snapMode: Slider.SnapAlways
                                     value: graph3d.cuboidH; onMoved: graph3d.cuboidH = value }
                            Label { Layout.preferredWidth: 14; horizontalAlignment: Text.AlignRight; color: Theme.textMuted
                                    font.pixelSize: 11; text: Math.round(graph3d.cuboidH) }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            Label { text: "D"; color: "#3b82f6"; font.bold: true; font.pixelSize: 12; Layout.preferredWidth: 14 }
                            Slider { Layout.fillWidth: true; from: 1; to: 5; stepSize: 1; snapMode: Slider.SnapAlways
                                     value: graph3d.cuboidD; onMoved: graph3d.cuboidD = value }
                            Label { Layout.preferredWidth: 14; horizontalAlignment: Text.AlignRight; color: Theme.textMuted
                                    font.pixelSize: 11; text: Math.round(graph3d.cuboidD) }
                        }
                    }
                    // Globe opacity — shown only in the globe layout. Lower it to see
                    // cities / routes on the far side through a translucent Earth.
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        visible: win.use3D && graph3d.globeMode
                        Label { text: "Globe α"; color: Theme.textMuted; font.pixelSize: 12; Layout.preferredWidth: 66 }
                        Slider { Layout.fillWidth: true; from: 0.1; to: 1.0
                                 value: graph3d.globeOpacity; onMoved: graph3d.globeOpacity = value }
                        Label { Layout.preferredWidth: 28; horizontalAlignment: Text.AlignRight; color: Theme.textMuted
                                font.pixelSize: 11; text: graph3d.globeOpacity.toFixed(2) }
                    }
                }

                MenuSeparator { Layout.fillWidth: true }

                // ===== Style / Colours / Selection — the active view's appearance. =====
                Controls2D {
                    Layout.fillWidth: true; visible: !controlPane.win.use3D
                    gv: controlPane.graph; win: controlPane.win
                    onColorRequested: (role) => controlPane.win.openColor(role)
                }
                Controls3D {
                    Layout.fillWidth: true; visible: controlPane.win.use3D
                    view: controlPane.graph3d; win: controlPane.win
                    onColorRequested: (role) => controlPane.win.openColor(role)
                }
            }   // end content ColumnLayout
        }   // end ScrollView

        // Pinned live-utilisation monitor (CPU / RAM / GPU + this app), collapsible.
        LiveUtilization {
            Layout.fillWidth: true
            active: controlPane.win.page === "visualizer"
            expanded: controlPane.win.secMonitor
            onToggled: controlPane.win.secMonitor = !controlPane.win.secMonitor
        }
    }   // end panel ColumnLayout
}
