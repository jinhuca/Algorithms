pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window
import GraphVis
import UiKit

ApplicationWindow {
    id: win
    visible: true
    x: 120; y: 80; width: 1680; height: 900
    // Minimum size (VS-style): the title bar's middle region (version + pickers)
    // collapses/clips as the window narrows, so we only need room for the app title
    // + the window min/max/close buttons (plus the body's panel+canvas minimums).
    minimumWidth: 720
    minimumHeight: 540
    title: "Graph Algorithm Studio"
    color: Theme.windowBg
    flags: Qt.Window | Qt.FramelessWindowHint

    // Which workspace is on screen: "home" (landing), "visualizer" (the graph
    // canvas), or "analyzer" (headless benchmarks). The title bar hides the
    // visualizer-only pickers off the visualizer page and offers a Home button.
    property string page: "home"
    function goHome() { win.stopPlay(); graph.edgeMode = false; win.page = "home"; }
    function showVisualizer() { win.page = "visualizer"; }
    function showAnalyzer() { win.stopPlay(); graph.edgeMode = false; win.page = "analyzer"; }
    function showKnowledge() { win.stopPlay(); graph.edgeMode = false; win.page = "knowledge"; }

    // Selected UI theme (see UiPalette.themeNames). Empty until migrated from the
    // legacy darkMode bool in Component.onCompleted, then persisted on its own.
    property string themeName: ""
    // User-chosen accent that overrides the active theme's preset accent;
    // `transparent` = none (use the theme's accent). Persisted below.
    property color userAccent: "transparent"
    property bool darkMode: true         // legacy — kept only to migrate old settings
    property bool use3D: false           // swap the 2D canvas for the 3D view (title-bar switch)
    onUse3DChanged: if (use3D) graph3d.fit()
    property bool _maxed: false
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
    readonly property bool isShortestAlgo: win.activeAlgo === "Dijkstra" || win.activeAlgo === "Bellman-Ford"

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
        var e = { name: win.baseName(p), path: p };
        var list = [e];
        for (var i = 0; i < win.recentFiles.length; i++)
            if (win.recentFiles[i].path !== p) list.push(win.recentFiles[i]);
        if (list.length > 10) list = list.slice(0, 10);
        win.recentFiles = list;
    }

    // Shared colour picker for the Style tab: open it seeded with a role's current
    // colour; on accept, route the chosen colour back to the active view's role.
    function openColor(role) {
        dialogs.openColor(role, use3D ? graph3d.colorForRole(role) : graph.colorForRole(role));
    }
    // Busy while a file is read/parsed off-thread OR the canvas is still ramping
    // in a large graph's delegates — gates Run/Play and drives the overlay.
    readonly property bool busy: ctl.loading || graph.rendering || graph3d.preparing
    function toggleMaximize() { if (_maxed) { showNormal(); _maxed = false; } else { showMaximized(); _maxed = true; } }

    // Full-screen canvas: hide the control panel and take the window fullscreen;
    // a compact run bar on the canvas keeps the algorithm runnable. Esc exits.
    property bool canvasFull: false
    // Persisted position of the full-screen run bar (UNSET = default bottom-centre).
    property real runX: -1000000
    property real runY: -1000000
    function panePos(v, def, extent) { var p = (v <= -999999) ? def : v; return Math.max(0, Math.min(Math.max(0, extent), p)); }
    onCanvasFullChanged: visibility = canvasFull ? Window.FullScreen : Window.Windowed
    Shortcut { sequence: "Escape"; enabled: win.canvasFull; onActivated: win.canvasFull = false }
    // Escape (when not in full screen) clears the node + edge selection in both views.
    Shortcut {
        sequence: "Escape"; enabled: !win.canvasFull
        onActivated: { graph.clearSel(); graph.clearEdgeSel(); graph3d.clearSel(); graph3d.clearEdgeSel(); }
    }

    Settings {
        property alias winX: win.x
        property alias winY: win.y
        property alias winWidth: win.width
        property alias winHeight: win.height
        property alias darkMode: win.darkMode     // legacy (migrated to themeName)
        property alias themeName: win.themeName
        property alias userAccent: win.userAccent
        property alias use3D: win.use3D
    }
    // Remember which control-panel sections the user collapsed.
    Settings {
        category: "panel"
        property alias secDataSets: win.secDataSets
        property alias secSelected: win.secSelected
        property alias secBuildGraph: win.secBuildGraph
        property alias secViewMode: win.secViewMode
        property alias secMonitor: win.secMonitor
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
        property alias runX: win.runX
        property alias runY: win.runY
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
    // The selected theme flows into the shared palette; the app's Theme delegates to it.
    Binding { target: UiPalette; property: "themeName"; value: win.themeName }
    // User accent override (transparent = use the theme's preset accent).
    Binding { target: UiPalette; property: "accentOverride"; value: win.userAccent }

    // Drive the Controls palette from the theme.
    palette.window: Theme.windowBg
    palette.windowText: Theme.textPrimary
    palette.base: Theme.panelBg
    palette.text: Theme.textPrimary
    palette.button: Theme.button
    palette.buttonText: Theme.textPrimary
    palette.highlight: Theme.accent
    palette.highlightedText: "#ffffff"
    palette.mid: Theme.panelBorder

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
    function graphTooBig(nodes, edges) { return nodes > win.bigGraphNodes || edges > win.bigGraphEdges; }
    property string _skippedDoc: ""     // doc JSON the restore declined to auto-open
    property string _skippedFile: ""    // its originating file (if any)
    property string _skippedName: ""    // its document name
    property int _skippedNodes: 0       // node count (for the notice text)
    property bool _skippedModified: false

    // ---- unsaved-changes tracking + guard (shared by the 2D and 3D views, since
    // both edit the one controller graph) ----
    property bool modified: false       // graph data changed since the last load/save
    property bool _applying: false      // suppress dirty-tracking during programmatic (re)loads
    function markModified() { if (!win._applying) win.modified = true; }
    function markClean() { win.modified = false; }
    function stopPlay() { player.running = false; }   // halt algorithm playback (used on load/paste)

    // ---- view/UI configuration (travels with the document, saved to file + the
    // restored session) ----
    function collectView() {
        return {
            use3D: win.use3D,
            v2d: { style: graph.exportStyle(), showGrid: graph.showGrid,
                   showLabels: graph.showLabels, showLegend: graph.showLegend },
            v3d: { style: graph3d.exportStyle3D(), showGrid: graph3d.showGrid3d,
                   showLabels: graph3d.showLabels, showLegend: graph3d.showLegend3d }
        };
    }
    function applyView(v) {
        if (!v) return;
        win._applying = true;
        if (v.use3D !== undefined) win.use3D = v.use3D;
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
        win._applying = false;
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
    function histSnapshot() { win.syncViewConfig(); return ctl.toJson(); }
    function histRecordNow() {
        if (win._restoring) return;
        var snap = win.histSnapshot();
        var h = (win.histIndex < win.history.length - 1)
                ? win.history.slice(0, win.histIndex + 1) : win.history.slice();
        if (h.length && h[h.length - 1] === snap) return;   // nothing actually changed
        h.push(snap);
        while (h.length > 40) h.shift();                    // bounded history
        win.history = h; win.histIndex = h.length - 1;
    }
    Timer { id: histTimer; interval: 350; repeat: false; onTriggered: win.histRecordNow() }
    // Debounced record — coalesces a drag / slider sweep into one undo step.
    function histRecord() { if (win._restoring || win._applying) return; histTimer.restart(); }
    function histFlush() { if (histTimer.running) { histTimer.stop(); win.histRecordNow(); } }
    function histReset() { win.history = [win.histSnapshot()]; win.histIndex = 0; }   // fresh baseline after a load
    function histRestore(doc) {
        win._restoring = true; win._applying = true;
        graph.beginLoad(); ctl.loadJson(doc); graph.populate();
        win.applyViewFromCtl();
        graph.fitView(); if (win.use3D) graph3d.fit();
        win._applying = false; win._restoring = false;
    }
    function undoAll() { win.histFlush(); if (win.histIndex > 0) { win.histIndex--; win.histRestore(win.history[win.histIndex]); } }
    function redoAll() { if (win.histIndex < win.history.length - 1) { win.histIndex++; win.histRestore(win.history[win.histIndex]); } }
    // Load the large graph the launch guard skipped (user chose "Open anyway").
    // This blocks while the big scene builds — that's the deliberate opt-in.
    function openSkipped() {
        if (!win._skippedDoc.length) return;
        player.running = false; graph.edgeMode = false;
        win._applying = true;
        graph.beginLoad();
        var ok = ctl.loadJson(win._skippedDoc);
        graph.populate();
        win._applying = false;
        if (ok) {
            win.applyViewFromCtl();
            win.currentFile = win._skippedFile;
            win.docName = win._skippedName;
            win.modified = win._skippedModified;
            graph.fitView();
            if (win.use3D) graph3d.fit();
            win.histReset();
        }
        win._skippedDoc = ""; win._skippedFile = ""; win._skippedName = "";
        win._skippedNodes = 0; win._skippedModified = false;
    }

    // ---- session autosave (restore the last document on next launch) ----
    property bool _ready: false         // true once startup has settled (gates autosave)
    function scheduleAutosave() { if (win._ready) sessionTimer.restart(); }
    function autosaveSession() {
        // A large graph the launch guard skipped is still the stored session; don't
        // overwrite it with the fallback demo until the user opens or dismisses it,
        // so the "Open anyway" offer survives a plain close/relaunch.
        if (win._skippedDoc.length) return;
        win.syncViewConfig();
        sessionStore.data = JSON.stringify({ doc: ctl.toJson(), file: win.currentFile,
                                             docName: win.docName, modified: win.modified });
    }
    Timer { id: sessionTimer; interval: 800; onTriggered: win.autosaveSession() }

    // confirmUnsaved(proceed[, cancel]): if the document is clean, run proceed()
    // now; otherwise ask Save / Discard / Cancel and run the matching action.
    property var _proceed: null
    property var _cancel: null
    property bool _savePending: false   // a Save-As dialog is resolving as part of a guard
    function confirmUnsaved(proceed, cancel) {
        if (!win.modified) { proceed(); return; }
        win._proceed = proceed; win._cancel = cancel || null;
        dialogs.openUnsaved();
    }
    function _finishSave() {             // a Save completed -> continue the guarded action
        win._savePending = false; win.markClean();
        var p = win._proceed; win._proceed = null; win._cancel = null;
        if (p) p();
    }
    function _guardSave() {               // "Save" button
        if (win.currentFile.length) { win.syncViewConfig(); ctl.saveToFile(win.currentFile); win._finishSave(); }
        else { win._savePending = true; dialogs.openSave(false); }   // finishes in saveDialog.onAccepted
    }
    function _guardDiscard() {            // "Discard" button
        var p = win._proceed; win._proceed = null; win._cancel = null;
        if (p) p();
    }
    function _guardCancel() {             // "Cancel" button / Esc
        var c = win._cancel; win._proceed = null; win._cancel = null; win._savePending = false;
        if (c) c();
    }
    // Close-confirmation: veto the first close when modified, ask, then close.
    property bool _forceClose: false
    onClosing: function (close) {
        if (win._ready) win.autosaveSession();   // remember the last document for next launch
        if (win.modified && !win._forceClose) {
            close.accepted = false;
            win.confirmUnsaved(function () { win._forceClose = true; win.close(); });
        }
    }

    // If the restored window geometry (winX/winY, persisted above) lands off every
    // currently-connected monitor — common after unplugging a monitor the app was
    // last shown on — the frameless window becomes unreachable: it's running (in the
    // taskbar) but visible on no screen, and there's no title bar to drag it back.
    // Pull it back onto a real screen. Runs at startup, after Settings has restored.
    function ensureOnScreen() {
        var screens = Application.screens;
        if (!screens || screens.length === 0)
            return;
        var need = 120;                       // px of the window that must stay visible
        var wr = win.x + win.width, wb = win.y + win.height;
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i];
            var ix = Math.max(win.x, s.virtualX);
            var iy = Math.max(win.y, s.virtualY);
            var ixr = Math.min(wr, s.virtualX + s.width);
            var iyb = Math.min(wb, s.virtualY + s.height);
            if (ixr - ix >= need && iyb - iy >= need)
                return;                       // enough of it shows on this screen — keep it
        }
        // Off every screen: clamp the size to the primary screen and recentre there.
        var p = screens[0];
        win.width = Math.min(win.width, p.width - 80);
        win.height = Math.min(win.height, p.height - 80);
        win.x = p.virtualX + Math.round((p.width - win.width) / 2);
        win.y = p.virtualY + Math.round((p.height - win.height) / 2);
    }

    // On launch: (1) a .json on the command line wins; else (2) restore the last
    // session (graph + view config); else (3) keep the default "Weighted demo"
    // the controller loaded in its constructor.
    Component.onCompleted: {
        ensureOnScreen();                     // rescue an off-screen restored position
        // One-time migration: existing installs persisted only the darkMode bool.
        if (!win.themeName) win.themeName = win.darkMode ? "dark" : "light";
        var args = Qt.application.arguments;
        for (var i = 1; i < args.length; i++) {
            if (args[i].toLowerCase().endsWith(".json")) {
                var u = "file:///" + ("" + args[i]).replace(/\\/g, "/");
                win.currentFile = u; win.docName = win.baseName(u);
                win.addRecent(u);
                ctl.loadFromFileAsync(u);       // applyViewFromCtl runs on completion
                win._ready = true;
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
                    if (win.graphTooBig(nN, nE)) {
                        win._skippedDoc = d.doc; win._skippedFile = d.file || "";
                        win._skippedName = d.docName || "untitled";
                        win._skippedNodes = nN; win._skippedModified = !!d.modified;
                    } else {
                        win._applying = true;
                        graph.beginLoad();
                        var ok = ctl.loadJson(d.doc);
                        graph.populate();
                        win._applying = false;
                        if (ok) {
                            win.applyViewFromCtl();                 // use3D + toggles + style
                            win.currentFile = d.file || "";
                            win.docName = d.docName || "untitled";
                            win.modified = !!d.modified;
                            // (Not added to recentFiles — the restored doc is from the
                            // previous session; the list is current-session only.)
                            graph.fitView();
                            if (win.use3D) graph3d.fit();
                        }
                    }
                }
            } catch (e) { /* corrupt session — fall through to the default demo */ }
        }
        win._ready = true;
        win.histReset();            // undo baseline for the startup document
    }

    Shortcut { sequences: [StandardKey.Undo]; onActivated: win.undoAll() }
    Shortcut { sequences: [StandardKey.Redo, "Ctrl+Y"]; onActivated: win.redoAll() }

    // Any graph-data change (edit, drag, layout, directed toggle) marks the
    // document dirty and schedules a session autosave — unless we're applying
    // a programmatic (re)load. (The run bar's Path-to / Destination combos follow
    // ctl.pathChanged inside RunBar.qml.)
    Connections {
        target: ctl
        function onGraphChanged() { win.markModified(); win.scheduleAutosave(); }
    }
    // The 3D arrangement (cuboid re-layout, node drag, X/Y/Z sliders) is view-only
    // — it doesn't emit graphChanged — so schedule a session autosave when it moves
    // (posRev bumps on any such change) so the layout survives the next launch.
    Connections {
        target: graph3d
        function onPosRevChanged() { win.scheduleAutosave(); }
    }

    header: TitleBar {
        // The title names the current workspace (just the Studio on the home page).
        title: win.page === "analyzer" ? "Graph Algorithm Analyzer"
             : win.page === "visualizer" ? "Graph Algorithm Visualizer"
             : win.page === "knowledge" ? "Graph Knowledge Base"
             : "Graph Algorithm Studio"
        version: Qt.application.version
        page: win.page
        themeName: win.themeName
        themeNames: UiPalette.themeNames
        accentColor: UiPalette.accent          // effective accent (override or preset)
        accentIsCustom: win.userAccent.a > 0
        maximized: win._maxed
        win: win; ctl: ctl; graph: graph; graph3d: graph3d; dialogs: dialogs
        onMoveRequested: win.startSystemMove()
        onMaximizeToggled: win.toggleMaximize()
        onMinimizeRequested: win.showMinimized()
        onCloseRequested: win.close()
        onHomeRequested: win.goHome()
        onThemeSelected: (name) => win.themeName = name
        onAccentPickRequested: dialogs.openAccent(UiPalette.accent)
        onAccentResetRequested: win.userAccent = "transparent"
    }

    // Frameless resize handles (thin strips on the edges).
    Item {
        anchors.fill: parent; z: 100
        MouseArea { width: 6; anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
                    cursorShape: Qt.SizeHorCursor; onPressed: win.startSystemResize(Qt.LeftEdge) }
        MouseArea { width: 6; anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                    cursorShape: Qt.SizeHorCursor; onPressed: win.startSystemResize(Qt.RightEdge) }
        MouseArea { height: 6; anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    cursorShape: Qt.SizeVerCursor; onPressed: win.startSystemResize(Qt.BottomEdge) }
        MouseArea { width: 12; height: 12; anchors { right: parent.right; bottom: parent.bottom }
                    cursorShape: Qt.SizeFDiagCursor; onPressed: win.startSystemResize(Qt.RightEdge | Qt.BottomEdge) }
    }

    // Playback clock. Speed (steps/sec) is the source of truth here; the run bar's
    // Speed slider reads/writes win.playSpeed.
    property real playSpeed: 4          // 1..12 — matches the Speed slider range
    Timer {
        id: player; interval: Math.round(1100 / win.playSpeed); repeat: true
        onTriggered: { ctl.stepForward(); if (ctl.cursor >= ctl.stepCount - 1) running = false; }
    }

    // All dialogs (save / load, unsaved-changes prompt, colour picker, paste edge
    // list) live in Dialogs.qml; the window drives them via its public functions.
    Dialogs { id: dialogs; win: win; ctl: ctl; graph: graph; graph3d: graph3d }
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
                win._applying = true; graph.beginLoad();
                if (win.use3D) graph3d.preparing = true;
            } else if (win.use3D) {
                // Parse done, applyDoc already ran with labels suppressed. The apply
                // (populate / view / fit) blocks the GUI thread, so run it only AFTER a
                // frame carrying the overlay has actually been presented (beginPrepare3D),
                // otherwise the "Preparing…" message never gets painted.
                win.beginPrepare3D(function () {
                    graph.populate();
                    win.applyViewFromCtl();
                    graph.fitView();
                    graph3d.fit();
                    win.markClean(); win._applying = false;
                    win.histReset();            // fresh undo baseline for the loaded doc
                });
            } else {
                graph.populate();
                win.applyViewFromCtl();         // restore the file's saved view config
                graph.fitView();
                win.markClean(); win._applying = false;
                graph3d.preparing = false;
                win.histReset();
            }
        }
        // Any controller edit (add/delete vertex or edge, weight, relayout, circular,
        // clear, directed, paste, addVertices) lands here → record one undo step.
        function onGraphChanged() { win.histRecord(); }
    }
    // View-side edits that never touch the controller — 3D node drag / X-Y-Z sliders /
    // cuboid re-lay (posRev), 3D colours / scales (styleRev), 2D colours (styleRev) —
    // are debounced into undo steps too. (selRev / selection is deliberately ignored.)
    Connections { target: graph3d
        function onPosRevChanged() { win.histRecord(); }
        function onStyleRevChanged() { win.histRecord(); }
        // The 3D load gate just cleared → the scene is genuinely live (the "Rendering…"
        // overlay stayed up through the render-thread settle). Show the "Scene ready"
        // badge and leave it up until the user actually touches the scene, so it can
        // never fade while the scene is still frozen.
        function onPreparingChanged() {
            if (!graph3d.preparing) { win.sceneReadyMsg = true; readyFallback.restart(); }
        }
        // User's first touch of the live scene dismisses the badge.
        function onInteracted() {
            if (win.sceneReadyMsg) { win.sceneReadyMsg = false; readyFallback.stop(); }
        }
    }
    property bool sceneReadyMsg: false
    // Backstop only: if the user never touches the scene, retire the badge after a
    // while so it doesn't linger forever. Normally dismissed by onInteracted.
    Timer { id: readyFallback; interval: 6000; onTriggered: win.sceneReadyMsg = false }
    Connections { target: graph
        function onStyleRevChanged() { win.histRecord(); }
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
        win._prepFn = fn;
        graph3d.preparing = true;        // labelBudget→0, overlay requested
        prepStart.ticks = 0; prepStart.running = true;
    }
    FrameAnimation {
        id: prepStart; running: false
        property int ticks: 0
        onTriggered: {
            if (++prepStart.ticks < 2) return;           // let the overlay frame present first
            prepStart.running = false; prepStart.ticks = 0;
            if (win._prepFn) { win._prepFn(); win._prepFn = null; }
            graph3d.rampLabels();                        // fill labels in gradually, not all at once
            win.startPrepGate();
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
                          && (now - graph3d.lastRebuildMs) >= win.prepSettleMs;
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
        anchors.margins: 12
        visible: win.page === "home"
        onAnalyzerRequested: win.showAnalyzer()
        onVisualizerRequested: win.showVisualizer()
        onKnowledgeRequested: win.showKnowledge()
    }

    // ---- Analyzer workspace (headless benchmarks; stub for now) ----
    AnalyzerPage {
        id: analyzerPage
        anchors.fill: parent
        anchors.margins: 12
        visible: win.page === "analyzer"
    }

    // ---- Knowledge workspace (curated reference for the algorithms / structures) ----
    KnowledgePage {
        anchors.fill: parent
        anchors.margins: 12
        visible: win.page === "knowledge"
        onVisualizeRequested: (algo) => { win.activeAlgo = algo; win.showVisualizer(); }
        onBenchmarkRequested: (algo) => { analyzerPage.selectAlgo(algo); win.showAnalyzer(); }
    }

    // ---- Visualizer workspace (the graph canvas) ----
    SplitView {
        id: mainSplit
        anchors.fill: parent
        anchors.margins: 12
        visible: win.page === "visualizer"
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
            visible: !win.canvasFull
            win: win; ctl: ctl; graph: graph; graph3d: graph3d; dialogs: dialogs
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
                visible: !win.use3D          // 2D ↔ 3D toggled from the title bar
                ctl: ctl
                canvasBg: Theme.canvasBg
                stepMs: Math.round(1100 / win.playSpeed)   // token travel tracks the play speed
                playing: player.running      // lock node dragging only while auto-playing
                canvasFull: win.canvasFull
                onFullScreenToggleRequested: win.canvasFull = !win.canvasFull
                onRealignRequested: { win.runX = -1000000; win.runY = -1000000; }
                // Undo/redo via the window's unified history.
                canUndo: win.canUndoAll; canRedo: win.canRedoAll
                onUndoRequested: win.undoAll(); onRedoRequested: win.redoAll()
                // Scene lock (shared with the 3D view via win.editLocked).
                locked: win.editLocked
                onLockToggleRequested: win.editLocked = !win.editLocked
                // Mark the currently-selected start vertex with a red ring.
                sourceVertex: runBar.sourceIndex
                // Document label for the on-canvas info pane (hide the .json suffix).
                docLabel: win.docName.replace(/\.json$/i, "") + (win.currentFile.length ? "" : "  (unsaved)")
            }

            // 3D view — occupies the same slot when the title-bar switch is on.
            // Reuses the 2D layout (each vertex's x,y on the ground plane) and the
            // same playback state, so Run/Play on the canvas bar drives both.
            GraphView3D {
                id: graph3d
                anchors.fill: parent
                anchors.margins: 4
                visible: win.use3D
                ctl: ctl
                stepMs: Math.round(1100 / win.playSpeed)   // token travel tracks the play speed
                playing: player.running
                canvasFull: win.canvasFull
                canUndo: win.canUndoAll; canRedo: win.canRedoAll
                onUndoRequested: win.undoAll(); onRedoRequested: win.redoAll()
                locked: win.editLocked
                onLockToggleRequested: win.editLocked = !win.editLocked
                onRealignRequested: { win.runX = -1000000; win.runY = -1000000; }   // reset the run bar too
                sourceVertex: runBar.sourceIndex
                // Share Add-edge mode + weight with the 2D view (one toggle drives both).
                edgeMode: graph.edgeMode
                newWeight: graph.newWeight
                docLabel: win.docName.replace(/\.json$/i, "") + (win.currentFile.length ? "" : "  (unsaved)")
                onFullScreenToggleRequested: win.canvasFull = !win.canvasFull
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
            BusyOverlay { win: win; ctl: ctl; graph3d: graph3d }

            // (The top-right canvas controls — Undo/Redo/Fill/Full screen — live
            // inside GraphView2D / GraphView3D, driven via canvasFull/fullScreen.)

            // Run + playback controls, docked on the lower-centre of the canvas —
            // the single source of truth (Algorithm / Source / Destination / Run,
            // transport, Speed / Seek / Path-to). See RunBar.qml.
            RunBar { id: runBar; win: win; ctl: ctl; player: player }
        }
    }
}
