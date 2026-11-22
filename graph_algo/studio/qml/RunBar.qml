pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import GraphVis
import UiKit

// The run + playback bar docked on the lower-centre of the canvas: the single
// source of truth for Algorithm / Source / Destination / Run, the playback
// transport, Speed / Seek, and the Path-to query. Draggable by the grip (or the
// bar background) and re-centred by the panes' "re-align". The window supplies
// itself, the controller and the shared playback clock.
Rectangle {
    id: root
    required property var win
    required property var ctl
    required property var player      // the playback Timer (owned by the window)
    // The chosen start vertex (the views draw a source marker from it).
    property alias sourceIndex: srcBox.currentIndex

    // Uniform pane button (mirrors Overlay2D): a UiButton at the pane's button height.
    component PaneBtn: UiButton { implicitHeight: 28 }

    // A playback-transport button with clear disabled affordances:
    //   · the glyph greys out (UiButton dims its own background, but not an
    //     overlaid Text, so we colour the glyph by `enabled` ourselves);
    //   · a plain arrow cursor replaces the bar's move cursor when disabled.
    // The cursor guard must be a SIBLING overlay, not a child of the button: a
    // disabled Qt item disables its children too, so a child MouseArea would get
    // no hover and the event would fall through to the drag handler underneath
    // (which shows Qt.SizeAllCursor — the "cross" the user saw).
    component TransportBtn: Item {
        id: tb
        property string glyph                 // Segoe Fluent Icons code point
        property string tip
        property bool on: true                // whether the action is available
        signal activated()

        Layout.preferredWidth: _runBarDefs.transportButtonWidth
        implicitHeight: inner.implicitHeight

        PaneBtn {
            id: inner
            anchors.fill: parent
            enabled: tb.on
            onClicked: tb.activated()
            Text {
                text: tb.glyph
                font.family: "Segoe Fluent Icons"
                font.pixelSize: _runBarDefs.playback_font_size
                color: inner.enabled ? "white" : UiPalette.textDisabled
                anchors.centerIn: parent
            }
            ToolTip.visible: inner.hovered
            ToolTip.text: tb.tip
        }
        // Active only while the button is disabled: shows a normal arrow and
        // swallows the press so it never reaches the bar's drag MouseArea.
        MouseArea {
            anchors.fill: parent
            enabled: !tb.on
            hoverEnabled: true
            cursorShape: Qt.ArrowCursor
        }
    }

    // Trace-note colour keyed to the event kind (keywords match the notes built in
    // VisualizerController_run.cpp), so different events read as different colours.
    function noteColor(note) {
        if (note.startsWith("start"))     return Theme.stSource;      // red
        if (note.startsWith("discover"))  return Theme.stFrontier;    // blue
        if (note.startsWith("visit"))     return Theme.stCurrent;     // yellow
        if (note.startsWith("finish"))    return Theme.stSettled;     // green
        if (note.startsWith("tree edge")) return Theme.stTreeEdge;    // green
        if (note.startsWith("relax") || note.startsWith("examine")) return Theme.stActiveEdge; // yellow
        if (note.startsWith("skip"))      return Theme.textMuted;     // grey
        return Theme.textPrimary;         // completion summaries / fallback
    }

    z: 60
    x: win.panePos(win.runX, (parent.width - width) / 2, parent.width - width)
    y: win.panePos(win.runY, parent.height - height - 16, parent.height - height)
    radius: 8
    color: Qt.rgba(Theme.panelBg.r, Theme.panelBg.g, Theme.panelBg.b, 0.92)
    border.color: Theme.panelBorder; border.width: 1
    implicitWidth: barRow.implicitWidth + _runBarDefs.barPadding
    implicitHeight: _runBarDefs.paneHeight

    // Keep the Path-to / Destination combos in step with the controller — a canvas
    // click, a fresh run, or Clear all drive pathTarget, and the combos follow.
    Connections {
        target: root.ctl
        function onPathChanged() {
            pathBox.currentIndex = root.ctl.pathTarget;
            destBox.currentIndex = root.ctl.pathTarget >= 0 ? root.ctl.pathTarget + 1 : 0;
        }
    }

    // Background drag: press anywhere on the bar (not just the grip) to move it,
    // and SWALLOW the press so it never falls through to the 3D orbit / 2D canvas
    // underneath. Declared before barCol, so the controls on top still get their
    // own clicks; only the bar's empty areas hit this.
    MouseArea {
        anchors.fill: parent
        preventStealing: true
        cursorShape: Qt.SizeAllCursor
        property real ox: 0; property real oy: 0
        onPressed: function (m) { var g = mapToItem(root.parent, m.x, m.y); ox = g.x - root.x; oy = g.y - root.y; }
        onPositionChanged: function (m) {
            if (!pressed) return;
            var g = mapToItem(root.parent, m.x, m.y);
            root.win.runX = Math.max(0, Math.min(root.parent.width - root.width, g.x - ox));
            root.win.runY = Math.max(0, Math.min(root.parent.height - root.height, g.y - oy));
        }
    }

    Label {
        anchors.left: parent.left; anchors.leftMargin: 12
        anchors.bottom: parent.top; anchors.bottomMargin: 4
        visible: root.ctl.hasPath
        text: root.ctl.pathSummary
        color: Theme.stPath;
        font.pixelSize: 16; font.bold: true
    }
    Label {
        anchors.left: parent.horizontalCenter; anchors.leftMargin: 160
        anchors.bottom: parent.top; anchors.bottomMargin: 4
        visible: root.ctl.hasRun && root.ctl.stepNote.length > 0
        text: root.ctl.stepNote
        color: root.noteColor(root.ctl.stepNote);
        font.pixelSize: 16; font.bold: true
    }

    // Single row: the bar's height is constant, and the per-step readouts use fixed
    // widths so its width doesn't jitter during playback either.
    RowLayout {
        id: barRow
        anchors.centerIn: parent
        spacing: _runBarDefs.barSpacing

        MouseArea {                               // drag grip — move the bar
            Layout.preferredWidth: _runBarDefs.gripWidth; Layout.fillHeight: true
            cursorShape: Qt.SizeAllCursor
            preventStealing: true
            property real ox: 0; property real oy: 0
            onPressed: function (m) { var g = mapToItem(root.parent, m.x, m.y); ox = g.x - root.x; oy = g.y - root.y; }
            onPositionChanged: function (m) {
                if (!pressed) return;
                var g = mapToItem(root.parent, m.x, m.y);
                root.win.runX = Math.max(0, Math.min(root.parent.width - root.width, g.x - ox));
                root.win.runY = Math.max(0, Math.min(root.parent.height - root.height, g.y - oy));
            }
            Text { anchors.centerIn: parent; text: "⠿"; color: Theme.textMuted; font.pixelSize: _runBarDefs.gripFontSize }
        }
        // Algorithm is chosen in the title bar (Category + Algorithm); Run reads
        // win.activeAlgo. Source / Dest / Path-to live here on the canvas run bar.
        Label { text: "Source"; color: Theme.textMuted; font.pixelSize: _runBarDefs.text_font_size }
        UiComboBox {
            id: srcBox
            Layout.preferredWidth: _runBarDefs.sourceComboWidth
            font.pixelSize: _runBarDefs.combobox_font_size
            font.bold: true
            model: root.win.nodeModel; textRole: "label"
        }
        // Destination — only meaningful for shortest-path algos; stays visible but
        // disabled otherwise so the bar width never changes. Index 0 is "— all —".
        Label { text: "Dest"; color: Theme.textMuted; font.pixelSize: _runBarDefs.text_font_size }
        UiComboBox {
            id: destBox
            enabled: root.win.isShortestAlgo
            Layout.preferredWidth: _runBarDefs.destComboWidth
            font.pixelSize: _runBarDefs.combobox_font_size
            font.bold: true
            model: {
                var a = ["all"];
                for (var i = 0; i < root.win.nodeModel.length; i++) a.push(root.win.nodeModel[i].label);
                return a;
            }
            ToolTip.visible: hovered
            ToolTip.text: "Destination for the shortest path — '— all —' computes the whole tree"
        }
        // Path-to query — highlight the source→vertex path (or click a node). Always
        // present; disabled until a run exists.
        Label { text: "Path to"; color: Theme.textMuted; font.pixelSize: _runBarDefs.text_font_size }
        UiComboBox {
            id: pathBox
            Layout.preferredWidth: _runBarDefs.pathComboWidth
            enabled: root.ctl.hasRun
            model: root.win.nodeModel
            textRole: "label"
            font.pixelSize: _runBarDefs.combobox_font_size
            font.bold: true
            onActivated: root.ctl.highlightPathTo(currentIndex)
            ToolTip.visible: hovered && root.ctl.hasRun
            ToolTip.text: "Highlight the path from the source to this vertex (or click a node on the canvas)"
        }
        PaneBtn {
            text: "✕";
            // text: "\u2573"
            Layout.preferredWidth: _runBarDefs.clearButtonWidth
            enabled: root.ctl.hasPath
            onClicked: root.ctl.clearPath()
            ToolTip.visible: hovered
            ToolTip.text: "Clear highlighted path"
        }
        PaneBtn {
            Layout.preferredWidth: _runBarDefs.run_button_width
            text: "Run";
            font.pixelSize: _runBarDefs.text_font_size
            font.weight: Font.DemiBold
            highlighted: true
            enabled: !root.win.busy && root.ctl.nodeCount > 0
            onClicked: {
                root.player.running = false;
                // Capture the destination BEFORE run(): a fresh run clears pathTarget,
                // which (via onPathChanged) would reset destBox before we could read it.
                var dest = (root.win.isShortestAlgo && destBox.currentIndex > 0)
                           ? destBox.currentIndex - 1 : -1;
                root.ctl.run(root.win.activeAlgo, srcBox.currentIndex);
                if (dest >= 0) {
                    root.ctl.seek(root.ctl.stepCount - 1);
                    root.ctl.highlightPathTo(dest);
                }
            }
            ToolTip.visible: hovered && !enabled
            ToolTip.text: root.win.busy ? "Wait for the graph to finish loading" : "Load or build a graph first"
        }
        // Run time (ms) — fixed width so it doesn't shift the transport.
        Label {
            Layout.preferredWidth: _runBarDefs.runTimeWidth
            text: root.ctl.hasRun ? ((root.ctl.runMs < 1 ? root.ctl.runMs.toFixed(3) : root.ctl.runMs.toFixed(1)) + " ms") : "not run"
            color: Theme.textMuted; font.pixelSize: _runBarDefs.labelFontSize
            elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
        }
        ToolDivider {}
        // Playback transport — all four share one width so they line up.
        TransportBtn {
            glyph: "\uE72C"; tip: "Restart"
            on: root.ctl.hasRun && !root.win.busy
            onActivated: { root.player.running = false; root.ctl.seek(0); }
        }
        TransportBtn {
            glyph: "\uE892"; tip: "Step back"
            on: root.ctl.hasRun && !root.win.busy && root.ctl.cursor > 0
            onActivated: { root.player.running = false; root.ctl.stepBack(); }
        }
        TransportBtn {
            glyph: root.player.running ? "\uE769" : "\uE768"
            tip: root.player.running ? "Pause" : "Play"
            on: root.ctl.hasRun && !root.win.busy
            onActivated: {
                if (root.player.running) root.player.running = false;
                else if (root.ctl.cursor >= root.ctl.stepCount - 1) { root.ctl.clearPath(); root.ctl.seek(0); root.player.running = true; }
                else root.player.running = true;
            }
        }
        TransportBtn {
            glyph: "\uE893"; tip: "Step forward"
            on: root.ctl.hasRun && !root.win.busy && root.ctl.cursor < root.ctl.stepCount - 1
            onActivated: { root.player.running = false; root.ctl.stepForward(); }
        }
        // step readout — takes the space of the old step + note labels so large
        // step counts fit (the trace/note moved above the bar). Fixed width, no jitter.
        Label {
            Layout.preferredWidth: _runBarDefs.stepWidth + _runBarDefs.noteWidth
            text: root.ctl.hasRun ? ("step " + (root.ctl.cursor + 1) + " / " + root.ctl.stepCount) : ""
            color: Theme.textMuted;
            font.pixelSize: _runBarDefs.labelFontSize
            elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
        }
        ToolDivider {}
        Label { text: "Speed"; color: Theme.textMuted; font.pixelSize: _runBarDefs.labelFontSize }
        Slider { Layout.preferredWidth: _runBarDefs.speedSliderWidth; from: 1; to: 12
                 value: root.win.playSpeed; onMoved: root.win.playSpeed = value }
        Label {
            Layout.preferredWidth: _runBarDefs.speedValueWidth; horizontalAlignment: Text.AlignRight
            text: (root.win.playSpeed / 1.1).toFixed(1) + " /s"
            color: Theme.textMuted; font.pixelSize: _runBarDefs.labelFontSize
        }
        ToolDivider {}
        Label { text: "Seek"; color: Theme.textMuted; font.pixelSize: _runBarDefs.labelFontSize }
        Slider {
            Layout.preferredWidth: _runBarDefs.seekSliderWidth
            from: 0; to: Math.max(0, root.ctl.stepCount - 1); value: root.ctl.cursor
            enabled: root.ctl.hasRun && !root.win.busy
            onMoved: { root.player.running = false; root.ctl.seek(Math.round(value)); }
        }
    }

    // Private constants for the run bar (pane size / spacing, field widths, fonts).
    QtObject {
        id: _runBarDefs
        property real run_button_width: 80
        property real text_font_size: 15
        property real combobox_font_size: 14
        property real playback_font_size: 18

        property real paneHeight: 40          // match the canvas panes (GraphView2D.paneH / Overlay3D)
        property real barSpacing: 8
        property real barPadding: 24          // implicitWidth slack around the row

        property real gripWidth: 16
        property real gripFontSize: 16
        property real labelFontSize: 14

        property real sourceComboWidth: 92
        property real destComboWidth: 92
        property real pathComboWidth: 110

        property real clearButtonWidth: 34
        property real runTimeWidth: 72

        property real transportButtonWidth: 40
        property real transportGlyphFontSize: 11

        property real stepWidth: 136
        property real noteWidth: 120

        property real speedValueWidth: 50
        property real speedSliderWidth: 60
        property real seekSliderWidth: 80
    }
}
