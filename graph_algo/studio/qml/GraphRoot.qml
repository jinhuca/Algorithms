pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window
import GraphVis
import UiKit

// Graph Algorithm Studio content, with no window chrome — the landing/analyzer/
// knowledge pages, the visualizer SplitView (control panel + 2D/3D canvas + run bar),
// the controller, the document/undo/autosave machinery and the 3D prepare-gate.
// Hosted two ways:
//   * standalone, inside this studio's thin Main.qml (frameless ApplicationWindow);
//   * embedded in the Algorithms umbrella, swapped in by a Loader.
// The host owns the window, saved geometry and theme; this root owns everything else
// and exposes `pageTitle`, `page`, `goHome()`, `canvasFull`, `modified`, `_ready`,
// `userAccent`, `autosaveSession()`, `confirmUnsaved()` plus the `visCtl`/`view2d`/
// `view3d`/`dlgs` object handles the host's title bar needs.
Item {
    id: root

    // Handles the host window / title bar reach in (child ids aren't visible outside).
    property alias visCtl: ctl       // the VisualizerController
    property alias view2d: graph     // the 2D canvas
    property alias view3d: graph3d   // the 3D canvas
    property alias dlgs: dialogs     // the shared dialogs

    // Controls this studio contributes to the umbrella title bar — graph's algorithm
    // pickers, data-set controls and accent swatch. `ComponentBehavior: Bound` keeps
    // this Component bound to GraphRoot, so `root` and the ctl/graph/graph3d/dialogs
    // ids resolve here even though the umbrella's title-bar Loader instantiates it.
    // (The standalone window's TitleBar.qml keeps its own inline copy of these.)
    property Component titleControls: graphTitleControls

    // Identity shown in the host (umbrella) title bar when this studio is active.
    // `version` is build-stamped (Major.Minor.Patch.Build from version.h via the controller).
    readonly property string iconSource: "qrc:/qt/qml/GraphVis/ga_logo.png"
    readonly property string version: ctl.appVersion   // build-stamped, from version.h
    Component {
        id: graphTitleControls
        RowLayout {
            spacing: 8

            // Visualizer-only pickers (algorithm + data set) — hidden off the canvas page.
            RowLayout {
                visible: root.page === "visualizer"
                spacing: 8

                Label { text: "Category"; color: UiPalette.dark ? "#e2e8f0" : "#1e293b"; font.pixelSize: 15; font.bold: true }
                UiComboBox {
                    Layout.preferredWidth: 96
                    Layout.alignment: Qt.AlignVCenter
                    model: root.algoCats
                    currentIndex: Math.max(0, root.algoCats.indexOf(root.catOf(root.activeAlgo)))
                    onActivated: root.activeAlgo = root.algosByCat[currentText][0]
                    ToolTip.visible: hovered; ToolTip.text: "Algorithm category"
                }

                Label { text: "Algorithm"; color: UiPalette.dark ? "#e2e8f0" : "#1e293b"; font.pixelSize: 15; font.bold: true }
                UiComboBox {
                    Layout.preferredWidth: 124
                    Layout.alignment: Qt.AlignVCenter
                    model: root.algosByCat[root.catOf(root.activeAlgo)]
                    currentIndex: Math.max(0, root.algosByCat[root.catOf(root.activeAlgo)].indexOf(root.activeAlgo))
                    onActivated: root.activeAlgo = currentText
                    ToolTip.visible: hovered; ToolTip.text: "Algorithm Run executes"
                }

                Label { text: "Data Set"; color: UiPalette.dark ? "#e2e8f0" : "#1e293b"; font.pixelSize: 15; font.bold: true }
                UiComboBox {
                    id: sampleBox
                    Layout.preferredWidth: 140
                    Layout.alignment: Qt.AlignVCenter
                    readonly property var recentNames: root.recentFiles.map(function (e) { return e.name; })
                    model: recentNames.concat(ctl.sampleNames())
                    displayText: root.docName.replace(/\.json$/i, "")
                    onActivated: {
                        var n = sampleBox.recentNames.length
                        if (currentIndex < n) {
                            // A recent file — reopen it (no-op if it's already current).
                            var rf = root.recentFiles[currentIndex];
                            if (!rf || rf.path === root.currentFile) return;
                            root.confirmUnsaved(function () {
                                root.stopPlay(); graph.edgeMode = false;
                                root.currentFile = rf.path; root.docName = root.baseName(rf.path);
                                root.addRecent(rf.path);
                                ctl.loadFromFileAsync(rf.path);
                            });
                        } else {
                            // A built-in sample (synchronous; behind the 3D "Preparing…" gate).
                            var name = currentText;
                            root.confirmUnsaved(function () {
                                root.stopPlay(); graph.edgeMode = false
                                var doLoad = function () {
                                    root._applying = true; graph.beginLoad(); ctl.loadNamedSample(name); graph.populate(); root._applying = false;
                                    graph.fitView(); if (root.use3D) graph3d.fit();
                                    root.currentFile = ""; root.docName = name; root.markClean();
                                    root.histReset();
                                };
                                if (root.use3D) root.beginPrepare3D(doLoad)
                                else doLoad()
                            });
                        }
                    }
                }

                UiButton {
                    Layout.preferredWidth: 92; Layout.alignment: Qt.AlignVCenter
                    leftPadding: 16; rightPadding: 16
                    text: "Load"
                    onClicked: root.confirmUnsaved(function () { dialogs.load(); })
                    ToolTip.visible: hovered; ToolTip.text: "Load a graph from JSON"
                }
                UiButton {
                    Layout.preferredWidth: 92; Layout.alignment: Qt.AlignVCenter
                    leftPadding: 16; rightPadding: 16
                    text: "Save"
                    onClicked: { if (root.currentFile.length) { root.syncViewConfig(); ctl.saveToFile(root.currentFile); root.markClean(); } else dialogs.openSave(false); }
                    ToolTip.visible: hovered; ToolTip.text: root.currentFile.length ? ("Save to " + root.baseName(root.currentFile)) : "Save to a file…"
                }
                UiButton {
                    Layout.preferredWidth: 92; Layout.alignment: Qt.AlignVCenter
                    leftPadding: 16; rightPadding: 16
                    text: "Save As"
                    onClicked: dialogs.openSave(true)
                    ToolTip.visible: hovered; ToolTip.text: "Save to a new file…"
                }
                UiButton {
                    Layout.preferredWidth: 92; Layout.alignment: Qt.AlignVCenter
                    leftPadding: 16; rightPadding: 16
                    text: "Clear"
                    onClicked: root.confirmUnsaved(function () {
                        root.stopPlay(); graph.edgeMode = false;
                        root._applying = true; ctl.clear(); root._applying = false;
                        root.currentFile = ""; root.docName = "untitled"; root.markClean();
                    })
                    ToolTip.visible: hovered; ToolTip.text: "Clear the whole graph"
                }
            }

            // (Accent swatch lives in the host title bar — global, next to Theme —
            // not here, so graph's slot holds only graph-specific controls.)
        }
    }

    // Which workspace is on screen: "home" (landing), "visualizer" (the graph
    // canvas), or "analyzer" (headless benchmarks). The title bar hides the
    // visualizer-only pickers off the visualizer page and offers a Home button.
    property string page: "home"
    function goHome() { root.stopPlay(); graph.edgeMode = false; root.page = "home"; }
    function showVisualizer() { root.page = "visualizer"; }
    function showAnalyzer() { root.stopPlay(); graph.edgeMode = false; root.page = "analyzer"; }
    function showKnowledge() { root.stopPlay(); graph.edgeMode = false; root.page = "knowledge"; }

    // Title the host window shows for the current page.
    readonly property string pageTitle:
          page === "analyzer"   ? "Graph Algorithm Analyzer"
        : page === "visualizer" ? "Graph Algorithm Visualizer"
        : page === "knowledge"  ? "Graph Knowledge Base"
        :                         "Graph Algorithm Studio"

    // User-chosen accent that overrides the active theme's preset accent;
    // `transparent` = none (use the theme's accent). Persisted below. Drives
    // UiPalette.accentOverride only when NOT embedded in the umbrella (which owns
    // the global accent); see the `embedded` flag and the gated Binding below.
    property color userAccent: "transparent"
    // True when hosted by the Algorithms umbrella (it owns the app-wide accent).
    property bool embedded: false
    property bool use3D: false           // swap the 2D canvas for the 3D view (title-bar switch)
    onUse3DChanged: if (use3D) graph3d.fit()
    // The algorithm Run executes — the single source of truth. The title bar's
    // Category + Algorithm dropdowns set it (see TitleBar.qml); the run bar reads it.
    property string activeAlgo: "BFS"
    // Category → algorithms map for the title-bar pickers. Picking a category offers
    // only its algorithms; catOf() derives the current category from activeAlgo so no
    // separate category state is stored.
    readonly property var algoCats: ["Traversal", "Shortest", "MST"]
    readonly property var algosByCat: ({
        "Traversal": ["BFS", "DFS"],
        "Shortest": ["Dijkstra", "Bellman-Ford"],
        "MST": ["Kruskal", "Prim"]
    })
    function catOf(algo) {
        for (var c in algosByCat) if (algosByCat[c].indexOf(algo) >= 0) return c;
        return "Traversal";
    }
    // Shortest-path algorithms carry distances and support a source→destination
    // query; traversals (BFS/DFS) don't. Drives the run bar's Destination combo.
    readonly property bool isShortestAlgo: root.activeAlgo === "Dijkstra" || root.activeAlgo === "Bellman-Ford"

    // Scene lock: when on, all editing gestures (drag / add / delete / rename /
    // add-edge) are blocked in both views so the graph can't be changed by accident.
    // Toggled from the canvas toolbars; also disables the Build Graph buttons.
    property bool editLocked: false
    onEditLockedChanged: if (editLocked) graph.edgeMode = false   // don't get stuck mid-add-edge

    // Last explicitly-chosen flat layout (Free-style / Force-directed / Circular), so
    // the Layout dropdown can reflect the current arrangement. Cuboid is shown
    // whenever the 3D view is actually in cuboid mode (incl. a restored document),
    // regardless of this.
    property string layoutKind: "Free-style"

    // Collapsed/expanded state of each control-panel section (persisted below).
    property bool secDataSets: true
    property bool secSelected: true
    property bool secBuildGraph: true
    property bool secViewMode: true
    property bool secMonitor: true     // live-utilisation monitor at the control-panel bottom

    // Files the user loaded *this session* (most-recent first), shown in the Selected
    // Data Set dropdown so any can be reopened. Each entry is { name, path }; `path`
    // is the file URL passed back to loadFromFileAsync. Deliberately NOT persisted —
    // relaunching starts with just the built-in samples.
    property var recentFiles: []
    function addRecent(url) {
        var p = "" + url; if (!p.length) return;
        var e = { name: root.baseName(p), path: p };
        var list = [e];
        for (var i = 0; i < root.recentFiles.length; i++)
            if (root.recentFiles[i].path !== p) list.push(root.recentFiles[i]);
        if (list.length > 10) list = list.slice(0, 10);
        root.recentFiles = list;
    }

    // Shared colour picker for the Style tab: open it seeded with a role's current
    // colour; on accept, route the chosen colour back to the active view's role.
    function openColor(role) {
        dialogs.openColor(role, use3D ? graph3d.colorForRole(role) : graph.colorForRole(role));
    }
    // Busy while a file is read/parsed off-thread OR the canvas is still ramping
    // in a large graph's delegates — gates Run/Play and drives the overlay.
    readonly property bool busy: ctl.loading || graph.rendering || graph3d.preparing

    // Full-screen canvas: hide the control panel and take the window fullscreen;
    // a compact run bar on the canvas keeps the algorithm runnable. Esc exits. The
    // host window binds its `visibility` to this.
    property bool canvasFull: false
    // Persisted position of the full-screen run bar (UNSET = default bottom-centre).
    property real runX: -1000000
    property real runY: -1000000
    function panePos(v, def, extent) { var p = (v <= -999999) ? def : v; return Math.max(0, Math.min(Math.max(0, extent), p)); }
    Shortcut { sequence: "Escape"; enabled: root.canvasFull; onActivated: root.canvasFull = false }
    // Escape (when not in full screen) clears the node + edge selection in both views.
    Shortcut {
        sequence: "Escape"; enabled: !root.canvasFull
        onActivated: { graph.clearSel(); graph.clearEdgeSel(); graph3d.clearSel(); graph3d.clearEdgeSel(); }
    }

    // View state persisted in the default settings group (kept there for backward
    // compatibility with existing standalone installs).
    Settings {
        property alias use3D: root.use3D
        property alias userAccent: root.userAccent
    }
    // Remember which control-panel sections the user collapsed.
    Settings {
        category: "panel"
        property alias secDataSets: root.secDataSets
        property alias secSelected: root.secSelected
        property alias secBuildGraph: root.secBuildGraph
        property alias secViewMode: root.secViewMode
        property alias secMonitor: root.secMonitor
    }
    // Persist the draggable canvas panes' positions across sessions.
    Settings {
        category: "canvasPanes"
        property alias infoX: graph.infoX
        property alias infoY: graph.infoY
        property alias editX: graph.editX
        property alias editY: graph.editY
        property alias zoomX: graph.zoomX
        property alias zoomY: graph.zoomY
        property alias runX: root.runX
        property alias runY: root.runY
        // 3D on-canvas panes.
        property alias info3dX: graph3d.info3dX
        property alias info3dY: graph3d.info3dY
        property alias ctl3dX: graph3d.ctl3dX
        property alias ctl3dY: graph3d.ctl3dY
    }
    // Persist the Style-tab appearance (scalar sizes + edge style + role colour
    // overrides) across sessions. Per-node colour overrides, selection, and 3D
    // positions are transient (not persisted) in this version.
    Settings {
        category: "style"
        property alias s2dNode: graph.nodeScale
        property alias s2dEdgeW: graph.edgeWidthScale
        property alias s2dArrow: graph.arrowScale
        property alias s2dLabel: graph.labelScale
        property alias s2dEdgeStyle: graph.edgeStyle
        property alias s2dCurve: graph.curvature
        property alias s2dcNode: graph.nodeFillOverride
        property alias s2dcEdge: graph.edgeOverride
        property alias s2dcLabel: graph.labelOverride
        property alias s2dcSrc: graph.srcOverride
        property alias s2dcFront: graph.frontierOverride
        property alias s2dcCur: graph.currentOverride
        property alias s2dcSet: graph.settledOverride
        property alias s3dNode: graph3d.nodeScale
        property alias s3dEdge: graph3d.edgeScale
        property alias s3dArrow: graph3d.arrowScale
        property alias s3dNodeLbl: graph3d.nodeLabelSize
        property alias s3dEdgeLbl: graph3d.edgeLabelSize
        property alias s3dEdgeStyle: graph3d.edge3dStyle
        property alias s3dCurve: graph3d.curvature3d
        property alias s3dAxes: graph3d.showAxes3d
        property alias s3dcNode: graph3d.nodeFillOverride
        property alias s3dcEdge: graph3d.edgeOverride
        property alias s3dcLabel: graph3d.labelOverride
        property alias s3dcSrc: graph3d.srcOverride
        property alias s3dcFront: graph3d.frontierOverride
        property alias s3dcCur: graph3d.currentOverride
        property alias s3dcSet: graph3d.settledOverride
    }
    // Full last-session document (graph + view config), auto-saved on change and
    // restored on launch so the app reopens the last data (see Component.onCompleted).
    Settings { id: sessionStore; category: "session"; property string data: "" }
    // User accent override (transparent = use the theme's preset accent).
    Binding { target: UiPalette; property: "accentOverride"; value: root.userAccent; when: !root.embedded }

    VisualizerController { id: ctl }

    // Current document: file path (empty when never saved), and a display name
    // for the on-canvas summary (file basename, sample name, or built source).
    property string currentFile: ""
    property string docName: "Weighted demo"
    // Cache the vertex list once per graphChanged. Binding a ComboBox's `model`
    // straight to `ctl.nodes` is O(n^2): the getter rebuilds the whole list on
    // every internal access (count/currentText/textAt), so a large graph froze
    // the load for ~20 s. The combos read this cached list instead.
    readonly property var nodeModel: ctl.nodes
    function baseName(url) { var s = "" + url; return decodeURIComponent(s.split('/').pop()); }

    // ---- large-graph guard ----
    // Safety net only: loads are now O(n) (see nodesJson/edgesJson) and 2D/3D use
    // LOD, so normal graphs auto-open instantly. This just avoids auto-opening an
    // extreme graph on launch; the user can still open it on demand via the notice.
    // See Component.onCompleted and the Files-section banner.
    readonly property int bigGraphNodes: 5000
    readonly property int bigGraphEdges: 8000
    function graphTooBig(nodes, edges) { return nodes > root.bigGraphNodes || edges > root.bigGraphEdges; }
    property string _skippedDoc: ""     // doc JSON the restore declined to auto-open
    property string _skippedFile: ""    // its originating file (if any)
    property string _skippedName: ""    // its document name
    property int _skippedNodes: 0       // node count (for the notice text)
    property bool _skippedModified: false

    // ---- unsaved-changes tracking + guard (shared by the 2D and 3D views, since
    // both edit the one controller graph) ----
    property bool modified: false       // graph data changed since the last load/save
    property bool _applying: false      // suppress dirty-tracking during programmatic (re)loads
    function markModified() { if (!root._applying) root.modified = true; }
    function markClean() { root.modified = false; }
    function stopPlay() { player.running = false; }   // halt algorithm playback (used on load/paste)

    // ---- view/UI configuration (travels with the document, saved to file + the
    // restored session) ----
    function collectView() {
        return {
            use3D: root.use3D,
            v2d: { style: graph.exportStyle(), showGrid: graph.showGrid,
                   showLabels: graph.showLabels, showLegend: graph.showLegend },
            v3d: { style: graph3d.exportStyle3D(), showGrid: graph3d.showGrid3d,
                   showLabels: graph3d.showLabels, showLegend: graph3d.showLegend3d }
        };
    }
    function applyView(v) {
        if (!v) return;
        root._applying = true;
        if (v.use3D !== undefined) root.use3D = v.use3D;
        if (v.v2d) {
            graph.importStyle(v.v2d.style);
            if (v.v2d.showGrid !== undefined) graph.showGrid = v.v2d.showGrid;
            if (v.v2d.showLabels !== undefined) graph.showLabels = v.v2d.showLabels;
            if (v.v2d.showLegend !== undefined) graph.showLegend = v.v2d.showLegend;
        }
        if (v.v3d) {
            graph3d.importStyle3D(v.v3d.style);
            if (v.v3d.showGrid !== undefined) graph3d.showGrid3d = v.v3d.showGrid;
            if (v.v3d.showLabels !== undefined) graph3d.showLabels = v.v3d.showLabels;
            if (v.v3d.showLegend !== undefined) graph3d.showLegend3d = v.v3d.showLegend;
        }
        root._applying = false;
    }
    // Push the current view config into the controller so saveToFile()/toJson()
    // include it. Called right before every save.
    function syncViewConfig() { ctl.viewConfig = JSON.stringify(collectView()); }
    // Apply the view config the controller parsed from a just-loaded document.
    function applyViewFromCtl() {
        var s = ctl.viewConfig;
        if (!s || !s.length) {
            // A config-less document (e.g. a minimal hand-written JSON) must still
            // clear the previous doc's 3D layout — otherwise its globe/cuboid lingers.
            graph3d.importStyle3D({});
            return;
        }
        try { applyView(JSON.parse(s)); } catch (e) {}
    }

    // ---- Unified undo / redo -------------------------------------------------
    // One history of whole-document snapshots — ctl.toJson() embeds the graph
    // (incl. node positions) AND the 2D/3D view config (colours, 3D pins, cuboid
    // layout). Recorded on a short debounce after ANY change, controller-side or
    // view-side, so from the user's perspective a single Ctrl+Z reverts the last
    // thing they did regardless of which layer owns it.
    property var history: []
    property int histIndex: -1
    property bool _restoring: false          // suppress recording while applying undo/redo
    readonly property bool canUndoAll: histIndex > 0
    readonly property bool canRedoAll: histIndex >= 0 && histIndex < history.length - 1
    function histSnapshot() { root.syncViewConfig(); return ctl.toJson(); }
    function histRecordNow() {
        if (root._restoring) return;
        var snap = root.histSnapshot();
        var h = (root.histIndex < root.history.length - 1)
                ? root.history.slice(0, root.histIndex + 1) : root.history.slice();
        if (h.length && h[h.length - 1] === snap) return;   // nothing actually changed
        h.push(snap);
        while (h.length > 40) h.shift();                    // bounded history
        root.history = h; root.histIndex = h.length - 1;
    }
    Timer { id: histTimer; interval: 350; repeat: false; onTriggered: root.histRecordNow() }
    // Debounced record — coalesces a drag / slider sweep into one undo step.
    function histRecord() { if (root._restoring || root._applying) return; histTimer.restart(); }
    function histFlush() { if (histTimer.running) { histTimer.stop(); root.histRecordNow(); } }
    function histReset() { root.history = [root.histSnapshot()]; root.histIndex = 0; }   // fresh baseline after a load
    function histRestore(doc) {
        root._restoring = true; root._applying = true;
        graph.beginLoad(); ctl.loadJson(doc); graph.populate();
        root.applyViewFromCtl();
        graph.fitView(); if (root.use3D) graph3d.fit();
        root._applying = false; root._restoring = false;
    }
    function undoAll() { root.histFlush(); if (root.histIndex > 0) { root.histIndex--; root.histRestore(root.history[root.histIndex]); } }
    function redoAll() { if (root.histIndex < root.history.length - 1) { root.histIndex++; root.histRestore(root.history[root.histIndex]); } }
    // Load the large graph the launch guard skipped (user chose "Open anyway").
    // This blocks while the big scene builds — that's the deliberate opt-in.
    function openSkipped() {
        if (!root._skippedDoc.length) return;
        player.running = false; graph.edgeMode = false;
        root._applying = true;
        graph.beginLoad();
        var ok = ctl.loadJson(root._skippedDoc);
        graph.populate();
        root._applying = false;
        if (ok) {
            root.applyViewFromCtl();
            root.currentFile = root._skippedFile;
            root.docName = root._skippedName;
            root.modified = root._skippedModified;
            graph.fitView();
            if (root.use3D) graph3d.fit();
            root.histReset();
        }
        root._skippedDoc = ""; root._skippedFile = ""; root._skippedName = "";
        root._skippedNodes = 0; root._skippedModified = false;
    }

    // ---- session autosave (restore the last document on next launch) ----
    property bool _ready: false         // true once startup has settled (gates autosave)
    function scheduleAutosave() { if (root._ready) sessionTimer.restart(); }
    function autosaveSession() {
        // A large graph the launch guard skipped is still the stored session; don't
        // overwrite it with the fallback demo until the user opens or dismisses it,
        // so the "Open anyway" offer survives a plain close/relaunch.
        if (root._skippedDoc.length) return;
        root.syncViewConfig();
        sessionStore.data = JSON.stringify({ doc: ctl.toJson(), file: root.currentFile,
                                             docName: root.docName, modified: root.modified });
    }
    Timer { id: sessionTimer; interval: 800; onTriggered: root.autosaveSession() }

    // confirmUnsaved(proceed[, cancel]): if the document is clean, run proceed()
    // now; otherwise ask Save / Discard / Cancel and run the matching action.
    property var _proceed: null
    property var _cancel: null
    property bool _savePending: false   // a Save-As dialog is resolving as part of a guard
    function confirmUnsaved(proceed, cancel) {
        if (!root.modified) { proceed(); return; }
        root._proceed = proceed; root._cancel = cancel || null;
        dialogs.openUnsaved();
    }
    function _finishSave() {             // a Save completed -> continue the guarded action
        root._savePending = false; root.markClean();
        var p = root._proceed; root._proceed = null; root._cancel = null;
        if (p) p();
    }
    function _guardSave() {               // "Save" button
        if (root.currentFile.length) { root.syncViewConfig(); ctl.saveToFile(root.currentFile); root._finishSave(); }
        else { root._savePending = true; dialogs.openSave(false); }   // finishes in saveDialog.onAccepted
    }
    function _guardDiscard() {            // "Discard" button
        var p = root._proceed; root._proceed = null; root._cancel = null;
        if (p) p();
    }
    function _guardCancel() {             // "Cancel" button / Esc
        var c = root._cancel; root._proceed = null; root._cancel = null; root._savePending = false;
        if (c) c();
    }

    // On launch: (1) a .json on the command line wins; else (2) restore the last
    // session (graph + view config); else (3) keep the default "Weighted demo"
    // the controller loaded in its constructor.
    Component.onCompleted: {
        var args = Qt.application.arguments;
        for (var i = 1; i < args.length; i++) {
            if (args[i].toLowerCase().endsWith(".json")) {
                var u = "file:///" + ("" + args[i]).replace(/\\/g, "/");
                root.currentFile = u; root.docName = root.baseName(u);
                root.addRecent(u);
                ctl.loadFromFileAsync(u);       // applyViewFromCtl runs on completion
                root._ready = true;
                return;
            }
        }
        if (sessionStore.data && sessionStore.data.length) {
            try {
                var d = JSON.parse(sessionStore.data);
                if (d && d.doc) {
                    // Peek at the size before loading: a very large graph freezes the
                    // UI for many seconds, so don't auto-open it on launch — stash it
                    // and offer "Open anyway" in the Files-section notice instead.
                    var pd = JSON.parse(d.doc);
                    var nN = (pd && pd.nodes) ? pd.nodes.length : 0;
                    var nE = (pd && pd.edges) ? pd.edges.length : 0;
                    if (root.graphTooBig(nN, nE)) {
                        root._skippedDoc = d.doc; root._skippedFile = d.file || "";
                        root._skippedName = d.docName || "untitled";
                        root._skippedNodes = nN; root._skippedModified = !!d.modified;
                    } else {
                        root._applying = true;
                        graph.beginLoad();
                        var ok = ctl.loadJson(d.doc);
                        graph.populate();
                        root._applying = false;
                        if (ok) {
                            root.applyViewFromCtl();                 // use3D + toggles + style
                            root.currentFile = d.file || "";
                            root.docName = d.docName || "untitled";
                            root.modified = !!d.modified;
                            // (Not added to recentFiles — the restored doc is from the
                            // previous session; the list is current-session only.)
                            graph.fitView();
                            if (root.use3D) graph3d.fit();
                        }
                    }
                }
            } catch (e) { /* corrupt session — fall through to the default demo */ }
        }
        root._ready = true;
        root.histReset();            // undo baseline for the startup document
    }

    Shortcut { sequences: [StandardKey.Undo]; onActivated: root.undoAll() }
    Shortcut { sequences: [StandardKey.Redo, "Ctrl+Y"]; onActivated: root.redoAll() }

    // Any graph-data change (edit, drag, layout, directed toggle) marks the
    // document dirty and schedules a session autosave — unless we're applying
    // a programmatic (re)load. (The run bar's Path-to / Destination combos follow
    // ctl.pathChanged inside RunBar.qml.)
    Connections {
        target: ctl
        function onGraphChanged() { root.markModified(); root.scheduleAutosave(); }
    }
    // The 3D arrangement (cuboid re-layout, node drag, X/Y/Z sliders) is view-only
    // — it doesn't emit graphChanged — so schedule a session autosave when it moves
    // (posRev bumps on any such change) so the layout survives the next launch.
    Connections {
        target: graph3d
        function onPosRevChanged() { root.scheduleAutosave(); }
    }

    // Playback clock. Speed (steps/sec) is the source of truth here; the run bar's
    // Speed slider reads/writes root.playSpeed.
    property real playSpeed: 4          // 1..12 — matches the Speed slider range
    Timer {
        id: player; interval: Math.round(1100 / root.playSpeed); repeat: true
        onTriggered: { ctl.stepForward(); if (ctl.cursor >= ctl.stepCount - 1) running = false; }
    }

    // All dialogs (save / load, unsaved-changes prompt, colour picker, paste edge
    // list) live in Dialogs.qml; the root drives them via its public functions.
    Dialogs { id: dialogs; win: root; ctl: ctl; graph: graph; graph3d: graph3d }
    // Gate instantiation before the data lands (loading starts), then populate
    // progressively + frame the graph once the async load finishes (populate
    // ramps big graphs in so the UI stays responsive).
    Connections {
        target: ctl
        function onLoadingChanged() {
            if (ctl.loading) {
                // Load initiated. Raise the gate NOW — before the off-thread parse
                // finishes and applyDoc mutates the graph — so the 3D view drops
                // labelBudget to 0 *before* nodeCount changes. Otherwise the label
                // Repeater3Ds mass-create a Node+Text per element and freeze the GUI
                // thread. (During the parse itself the GUI thread is free, so the
                // spinner animates.)
                root._applying = true; graph.beginLoad();
                if (root.use3D) graph3d.preparing = true;
            } else if (root.use3D) {
                // Parse done, applyDoc already ran with labels suppressed. The apply
                // (populate / view / fit) blocks the GUI thread, so run it only AFTER a
                // frame carrying the overlay has actually been presented (beginPrepare3D),
                // otherwise the "Preparing…" message never gets painted.
                root.beginPrepare3D(function () {
                    graph.populate();
                    root.applyViewFromCtl();
                    graph.fitView();
                    graph3d.fit();
                    root.markClean(); root._applying = false;
                    root.histReset();            // fresh undo baseline for the loaded doc
                });
            } else {
                graph.populate();
                root.applyViewFromCtl();         // restore the file's saved view config
                graph.fitView();
                root.markClean(); root._applying = false;
                graph3d.preparing = false;
                root.histReset();
            }
        }
        // Any controller edit (add/delete vertex or edge, weight, relayout, circular,
        // clear, directed, paste, addVertices) lands here → record one undo step.
        function onGraphChanged() { root.histRecord(); }
    }
    // View-side edits that never touch the controller — 3D node drag / X-Y-Z sliders /
    // cuboid re-lay (posRev), 3D colours / scales (styleRev), 2D colours (styleRev) —
    // are debounced into undo steps too. (selRev / selection is deliberately ignored.)
    Connections { target: graph3d
        function onPosRevChanged() { root.histRecord(); }
        function onStyleRevChanged() { root.histRecord(); }
        // The 3D load gate just cleared → the scene is genuinely live (the "Rendering…"
        // overlay stayed up through the render-thread settle). Show the "Scene ready"
        // badge and leave it up until the user actually touches the scene, so it can
        // never fade while the scene is still frozen.
        function onPreparingChanged() {
            if (!graph3d.preparing) { root.sceneReadyMsg = true; readyFallback.restart(); }
        }
        // User's first touch of the live scene dismisses the badge.
        function onInteracted() {
            if (root.sceneReadyMsg) { root.sceneReadyMsg = false; readyFallback.stop(); }
        }
    }
    property bool sceneReadyMsg: false
    // Backstop only: if the user never touches the scene, retire the badge after a
    // while so it doesn't linger forever. Normally dismissed by onInteracted.
    Timer { id: readyFallback; interval: 6000; onTriggered: root.sceneReadyMsg = false }
    Connections { target: graph
        function onStyleRevChanged() { root.histRecord(); }
    }
    // Hold the "Preparing…" gate (overlay + input block) until the scene renders
    // smoothly again — see prepFrames.
    function startPrepGate() {
        graph3d.preparing = true;
        // Anchor the settle window at gate start so it's measured from a real
        // timestamp even before the (debounced) rebuild stamps lastRebuildMs; each
        // actual buffer upload pushes it later again.
        graph3d.lastRebuildMs = Date.now();
        prepFrames.fast = 0; prepFrames.lastT = 0; prepFrames.running = true;
        prepSafety.restart();
    }
    // Run a blocking 3D load `fn` only after a frame with the "Preparing…" overlay has
    // been PRESENTED — an in-window overlay can't paint once the GUI thread is blocked,
    // so we must get it on screen first. FrameAnimation.onTriggered fires in the frame's
    // update phase (before that frame renders), so we wait two ticks: the first lets the
    // overlay frame render + present, the second runs the heavy work behind it.
    property var _prepFn: null
    function beginPrepare3D(fn) {
        root._prepFn = fn;
        graph3d.preparing = true;        // labelBudget→0, overlay requested
        prepStart.ticks = 0; prepStart.running = true;
    }
    FrameAnimation {
        id: prepStart; running: false
        property int ticks: 0
        onTriggered: {
            if (++prepStart.ticks < 2) return;           // let the overlay frame present first
            prepStart.running = false; prepStart.ticks = 0;
            if (root._prepFn) { root._prepFn(); root._prepFn = null; }
            graph3d.rampLabels();                        // fill labels in gradually, not all at once
            root.startPrepGate();
        }
    }
    // Clears the gate only once the scene is genuinely interactive — not merely once
    // the GUI thread stops stalling. Three conditions must hold together:
    //   (1) no progressive edge batches still pending (`!graph3d.building`);
    //   (2) a short settle has elapsed since the last instance-buffer upload
    //       (`lastRebuildMs`) — on a threaded render loop the GUI thread goes idle
    //       the instant setEntries returns, while the render thread keeps
    //       uploading/compiling for a while after; without this wait we'd see
    //       "smooth" GUI frames and fire "Scene ready" before the first orbit/zoom
    //       would actually respond;
    //   (3) a few consecutive quick frames (no GUI stall).
    // A stall, a pending batch, or a too-recent upload resets the count, so the
    // overlay stays up for the whole frozen period rather than a fixed, too-short delay.
    // Render-thread settle budget, scaled by scene size: the bigger the graph, the
    // longer the render thread keeps uploading/compiling after the GUI goes idle.
    // Small graphs stay snappy (floor 250ms); a ~1000-node/1000-edge scene gets
    // ~1.5s, matching the observed gap between "GUI idle" and "orbit responds".
    property int prepSettleMs: Math.max(250, Math.min(2000,
                                   Math.round((graph3d.nodeCount + graph3d.edgeCount) * 0.7)))
    FrameAnimation {
        id: prepFrames; running: false
        property double lastT: 0
        property int fast: 0
        onTriggered: {
            var now = Date.now();
            var dt = prepFrames.lastT ? (now - prepFrames.lastT) : 1000;
            prepFrames.lastT = now;
            var settled = !graph3d.building
                          && (now - graph3d.lastRebuildMs) >= root.prepSettleMs;
            if (dt < 40 && settled) {            // ~>25 fps, build done, render caught up
                if (++prepFrames.fast >= 5) {
                    prepFrames.running = false; prepSafety.stop();
                    graph3d.preparing = false;
                }
            } else {
                prepFrames.fast = 0;             // stalled / still building / too soon — keep waiting
            }
        }
    }
    // Fallback: force-clear the gate if frames never settle. Generous so it can't
    // fire mid-build on a very large graph (the batched edge build keeps frames
    // "busy" until it finishes).
    Timer { id: prepSafety; interval: 30000; repeat: false
            onTriggered: { prepFrames.running = false; graph3d.preparing = false; } }


    // ---- Studio landing page ----
    HomePage {
        anchors.fill: parent
        visible: root.page === "home"
        onAnalyzerRequested: root.showAnalyzer()
        onVisualizerRequested: root.showVisualizer()
        onKnowledgeRequested: root.showKnowledge()
    }

    // ---- Analyzer workspace (headless benchmarks; stub for now) ----
    AnalyzerPage {
        id: analyzerPage
        anchors.fill: parent
        visible: root.page === "analyzer"
    }

    // ---- Knowledge workspace (curated reference for the algorithms / structures) ----
    KnowledgePage {
        anchors.fill: parent
        visible: root.page === "knowledge"
        onVisualizeRequested: (algo) => { root.activeAlgo = algo; root.showVisualizer(); }
        onBenchmarkRequested: (algo) => { analyzerPage.selectAlgo(algo); root.showAnalyzer(); }
    }

    // ---- Visualizer workspace (the graph canvas) ----
    SplitView {
        id: mainSplit
        anchors.fill: parent
        visible: root.page === "visualizer"
        orientation: Qt.Horizontal

        // Wide, invisible-until-hovered resize handle (easy to grab).
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

        // ---- control panel (left) — see ControlPanel.qml ----
        ControlPanel {
            SplitView.preferredWidth: 280
            SplitView.minimumWidth: 240
            visible: !root.canvasFull
            win: root; ctl: ctl; graph: graph; graph3d: graph3d; dialogs: dialogs
        }

        // ---- canvas ----
        Frame {
            id: canvasPane
            SplitView.fillWidth: true
            SplitView.minimumWidth: 240
            clip: true
            background: Rectangle { color: Theme.panelBg; border.color: Theme.panelBorder; radius: 8 }
            GraphView2D {
                id: graph
                anchors.fill: parent
                anchors.margins: 4
                visible: !root.use3D          // 2D ↔ 3D toggled from the title bar
                ctl: ctl
                canvasBg: Theme.canvasBg
                stepMs: Math.round(1100 / root.playSpeed)   // token travel tracks the play speed
                playing: player.running      // lock node dragging only while auto-playing
                canvasFull: root.canvasFull
                onFullScreenToggleRequested: root.canvasFull = !root.canvasFull
                onRealignRequested: { root.runX = -1000000; root.runY = -1000000; }
                // Undo/redo via the root's unified history.
                canUndo: root.canUndoAll; canRedo: root.canRedoAll
                onUndoRequested: root.undoAll(); onRedoRequested: root.redoAll()
                // Scene lock (shared with the 3D view via root.editLocked).
                locked: root.editLocked
                onLockToggleRequested: root.editLocked = !root.editLocked
                // Mark the currently-selected start vertex with a red ring.
                sourceVertex: runBar.sourceIndex
                // Document label for the on-canvas info pane (hide the .json suffix).
                docLabel: root.docName.replace(/\.json$/i, "") + (root.currentFile.length ? "" : "  (unsaved)")
            }

            // 3D view — occupies the same slot when the title-bar switch is on.
            // Reuses the 2D layout (each vertex's x,y on the ground plane) and the
            // same playback state, so Run/Play on the canvas bar drives both.
            GraphView3D {
                id: graph3d
                anchors.fill: parent
                anchors.margins: 4
                visible: root.use3D
                ctl: ctl
                stepMs: Math.round(1100 / root.playSpeed)   // token travel tracks the play speed
                playing: player.running
                canvasFull: root.canvasFull
                canUndo: root.canUndoAll; canRedo: root.canRedoAll
                onUndoRequested: root.undoAll(); onRedoRequested: root.redoAll()
                locked: root.editLocked
                onLockToggleRequested: root.editLocked = !root.editLocked
                onRealignRequested: { root.runX = -1000000; root.runY = -1000000; }   // reset the run bar too
                sourceVertex: runBar.sourceIndex
                // Share Add-edge mode + weight with the 2D view (one toggle drives both).
                edgeMode: graph.edgeMode
                newWeight: graph.newWeight
                docLabel: root.docName.replace(/\.json$/i, "") + (root.currentFile.length ? "" : "  (unsaved)")
                onFullScreenToggleRequested: root.canvasFull = !root.canvasFull
                // Colours follow the Theme (light / dark + playback states).
                colBg: Theme.canvasBg
                colNodeFill: Theme.nodeFill
                colNodeBorder: Theme.nodeBorder
                colNodeText: Theme.nodeText
                colEdge: Theme.edge
                colFrontier: Theme.stFrontier
                colCurrent: Theme.stCurrent
                colSettled: Theme.stSettled
                colTreeEdge: Theme.stTreeEdge
                colActiveEdge: Theme.stActiveEdge
                colPath: Theme.stPath
                colSource: Theme.stSource
                colLabel: Theme.textPrimary
                colMuted: Theme.textMuted
                colPaneBg: Qt.rgba(Theme.panelBg.r, Theme.panelBg.g, Theme.panelBg.b, 0.92)
                colPaneBorder: Theme.panelBorder
                colSelect: Theme.accent
            }

            // Busy overlay (staged label + spinner) and the transient "Scene ready"
            // badge — see BusyOverlay.qml.
            BusyOverlay { win: root; ctl: ctl; graph3d: graph3d }

            // (The top-right canvas controls — Undo/Redo/Fill/Full screen — live
            // inside GraphView2D / GraphView3D, driven via canvasFull/fullScreen.)

            // Run + playback controls, docked on the lower-centre of the canvas —
            // the single source of truth (Algorithm / Source / Destination / Run,
            // transport, Speed / Seek / Path-to). See RunBar.qml.
            RunBar { id: runBar; win: root; ctl: ctl; player: player }
        }
    }
}
