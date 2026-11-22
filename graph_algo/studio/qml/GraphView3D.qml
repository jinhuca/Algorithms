pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick3D
import QtQuick3D.Helpers
import GraphVis

// 3D rendering of the graph, a drop-in for the canvas region (toggled from the
// title bar's 2D/3D switch). Vertices are spheres laid out on the ground (XZ)
// plane from their 2D x,y (so 2D and 3D share one layout); edges are tube +
// cone-arrowhead; names / weights / distances are billboarded labels. Orbit to
// rotate, wheel to zoom, right-drag to pan, Fit to reframe. Nodes drag on the
// ground plane and write back through ctl.moveVertex (locked while playing).
// Playback colouring mirrors the 2D view: node state colours, the result tree /
// active edge / highlighted path, the source marker and the current-node pulse.
GraphViewBase {
    id: root
    clip: true

    // ctl + node/edge selection + document snapshots come from GraphViewBase.
    property bool playing: false          // auto-play active → node dragging is locked
    property bool canvasFull: false       // mirrors the window full-screen state
    property int sourceVertex: -1         // currently-selected start vertex (red marker)
    // Add-edge mode (shared with the 2D view via Main): click a source node then a
    // target to connect them; dragging/orbit-select is suppressed while on.
    property int _lastNodeCount: 0        // tracks vertex-count changes (cuboid re-lay trigger)
    property bool edgeMode: false
    property int pendingSrc: -1           // first node picked in edge mode (-1 = none)
    property real newWeight: 1            // weight for a freshly drawn edge
    onEdgeModeChanged: pendingSrc = -1
    function connectTap(vid) {
        if (pendingSrc < 0) { pendingSrc = vid; return; }
        if (vid !== pendingSrc && ctl) ctl.addEdge(pendingSrc, vid, newWeight);
        pendingSrc = -1;
    }
    property bool showGrid3d: true        // floor grid on/off
    property bool showLabels: true        // vertex / weight / distance labels on/off
    property bool showLegend3d: true      // on-canvas state legend on/off
    property string docLabel: ""          // document name, bound from the window
    signal fullScreenToggleRequested()
    // Undo/redo route to the window's unified history (graph + view). canUndo/canRedo
    // are bound from Main; the toolbar buttons emit these.
    signal undoRequested()
    signal redoRequested()
    property bool canUndo: false
    property bool canRedo: false
    property bool locked: false          // scene lock: all editing gestures disabled
    signal lockToggleRequested()

    // --- draggable on-canvas panes (mirrors the 2D view) -----------------------
    // Each overlay pane carries a drag Grip and a persisted top-left; UNSET
    // (<= -1e6) uses the default anchored spot. realign() resets them all (and the
    // window's run bar, via realignRequested). See the shared Grip.qml.
    readonly property real paneUnset: -1000000
    property real info3dX: paneUnset; property real info3dY: paneUnset
    property real ctl3dX: paneUnset;  property real ctl3dY: paneUnset
    function paneClamp(v, def, extent) {
        var p = (v <= -999999) ? def : v;
        return Math.max(0, Math.min(Math.max(0, extent), p));
    }
    signal realignRequested()
    // Emitted on the user's first touch of the scene (press / orbit / zoom). Main
    // uses it to dismiss the "Scene ready" badge — it stays up until the user
    // actually acts on the scene, rather than fading on a timer.
    signal interacted()
    function realign() {
        info3dX = paneUnset; info3dY = paneUnset;
        ctl3dX = paneUnset; ctl3dY = paneUnset;
        realignRequested();
    }
    // Drag grip for the panes is the shared Grip.qml component (host: root).

    // Colours — bound from Main to the Theme (follow light/dark).
    property color colBg:        "#0b1220"
    property color colNodeFill:  "#1e293b"
    property color colNodeBorder:"#3b82f6"
    property color colNodeText:  "#e2e8f0"
    property color colEdge:      "#94a3b8"
    property color colFrontier:  "#3b82f6"
    property color colCurrent:   "#f59e0b"
    property color colSettled:   "#22c55e"
    // Theme-fed edge-state defaults (bound by Main). They feed the overridable
    // def* roles below, so the Colours section can retint them per-document.
    property color colTreeEdge:  "#22c55e"
    property color colActiveEdge:"#f59e0b"
    property color colPath:      "#ec4899"
    property color colSource:    "#ef4444"
    property color colLabel:     "#e2e8f0"
    property color colMuted:     "#94a3b8"
    property color colPaneBg:    "#e6111827"
    property color colPaneBorder:"#334155"
    property color colSelect:    "#3b82f6"   // selection accent (bound to Theme.accent by Main)

    // ---- appearance / style (driven by the Style tab's Controls3D) ----
    property real nodeScale: 1.0          // sphere size multiplier (0.2..2)
    property real edgeScale: 1.0          // tube thickness multiplier (0.1..2)
    property real arrowScale: 1.0         // arrowhead size multiplier (0.3..2)
    property int nodeLabelSize: 18        // state-name label font
    property int edgeLabelSize: 14        // edge (weight) label font
    property string edge3dStyle: "straight"  // "straight" | "curved"
    property real curvature3d: 0.25       // bow amount (0..1) when curved
    property real edgeOpacity: 0.55       // idle-edge alpha (thin, faint web for dense graphs)
    property bool showAxes3d: false       // X/Y/Z reference axes gizmo
    // Restore the edge appearance to its (thin, translucent) default.
    function resetEdges3D() {
        edgeScale = 1.0; edge3dStyle = "straight"; curvature3d = 0.25; edgeOpacity = 0.55;
        styleRev++; posRev++;
    }
    // True while a just-loaded scene is being built/uploaded (the first instance
    // rebuild + GPU upload briefly blocks). Drives a "Preparing scene…" overlay and
    // gates interaction; set/cleared by Main.qml around the post-load 3D work.
    property bool preparing: false
    onPreparingChanged: if (preparing) labelBudget = 0   // hide labels during the frozen apply

    // Wall-clock (ms) of the most recent instance-buffer upload (setEntries). The
    // readiness gate in Main waits a short settle past this before declaring the
    // scene interactive: the GUI thread goes idle as soon as the buffers are set,
    // but on a threaded render loop the render thread keeps uploading/compiling the
    // scene for a while after — so "smooth GUI frames" alone fire "Scene ready" too
    // early. Bumped at the end of every rebuild and on each progressive edge batch.
    property double lastRebuildMs: 0

    // How many per-vertex / per-edge text labels have been instantiated so far. The
    // label Repeater3Ds create a Node+Text each, which freezes the GUI thread if done
    // all at once on load — so after a load we ramp this up a batch per frame (see
    // rampLabels), keeping the UI responsive while labels fill in. A big default means
    // normal edits show every label immediately (no ramp).
    property int labelBudget: 100000
    Timer {
        id: labelRamp; interval: 16; repeat: true
        onTriggered: {
            var need = Math.max(root.nodeCount, root.edgeCount);
            if (root.labelBudget >= need) { root.labelBudget = 100000; labelRamp.stop(); return; }
            root.labelBudget += 24;      // a small batch per frame — fast, non-blocking
        }
    }
    // Restart the label ramp from zero (call when a load/show would otherwise create
    // the whole label set in one blocking burst).
    function rampLabels() { labelBudget = 0; labelRamp.restart(); }

    // Colour roles live in GraphViewBase; feed it this view's theme defaults (the
    // Main-bound col* inputs). Overrides, *Eff, workingColor/styleRev/nodeColors and
    // the colorForRole/applyColor/paintRole/resetColors helpers are all inherited.
    defNodeFill: colNodeFill
    defEdge: colEdge
    defLabel: colLabel
    defSource: colSource
    defFrontier: colFrontier
    defCurrent: colCurrent
    defSettled: colSettled
    defTreeEdge: colTreeEdge
    defActiveEdge: colActiveEdge
    defPathEdge: colPath
    defToken: colLabel        // indicator default tracks the (theme-adaptive) label colour

    // Effective arrowhead length (shared by the shaft trim and the cone model).
    readonly property real headLen: 18 * arrowScale

    // --- selection: a set of nodes (group move + styling). `selected` is the
    // "primary" (last-touched) member the position sliders use; `selectedSet`
    // drives the group drag and the per-node highlight. selRev bumps bindings. ---
    // Node/edge selection + colour roles (incl. nodeColors) are inherited from
    // GraphViewBase; the per-edge bend `edgeCurve` is view-specific and stays here.
    property var edgeCurve: ({})
    // One-line summary of the current selection for the on-canvas tip (overlay below).
    // Especially useful in 3D, where per-node labels only draw on small graphs.
    readonly property string selectionTip: {
        var _ = selRev;
        var nS = selCount(), eS = edgeSelCount();
        if (nS === 0 && eS === 0) return "";
        if (nS === 1 && eS === 0) {
            var nd = nodeArr[selected];
            if (!nd) return "";
            var t = "Node " + nd.label;
            var d = vdists.length > selected ? vdists[selected] : "";
            if (d && d.length) t += "   ·   distance " + d;
            return t;
        }
        if (eS === 1 && nS === 0) {
            var e = edgeArr[selectedEdge];
            if (!e) return "";
            var a = nodeArr[e.from], b = nodeArr[e.to];
            return "Edge " + (a ? a.label : e.from) + (directed ? "  →  " : "  —  ")
                 + (b ? b.label : e.to) + "   ·   weight " + e.weight;
        }
        var parts = [];
        if (nS) parts.push(nS + " node" + (nS > 1 ? "s" : ""));
        if (eS) parts.push(eS + " edge" + (eS > 1 ? "s" : ""));
        return parts.join(" + ") + " selected";
    }
    function selectedEdgeCurve() { return (selectedEdge >= 0 && edgeCurve[selectedEdge] !== undefined) ? edgeCurve[selectedEdge] : 0; }
    function setSelectedEdgeCurve(v) {
        var ids = _edgeSelIds(); if (ids.length === 0) return;
        var m = {}; for (var k in edgeCurve) m[k] = edgeCurve[k];
        for (var i = 0; i < ids.length; i++) m[ids[i]] = v;
        edgeCurve = m; selRev++; posRev++;
    }
    // Edge indices shift on add/remove, so drop the (transient) edge selection
    // when the edge count changes (not on a node drag).
    readonly property int _edgeCountWatch: (ctl && visible) ? ctl.edgeCount : 0
    on_EdgeCountWatchChanged: clearEdgeSel()

    // selectedNodeColor / applySelectedColor / clearSelectedColor are inherited.
    // Position editing lives in the cuboid layout (a true 3D arrangement); the flat
    // layout has no Y, so the sliders drive cuboidPos.
    readonly property real posRange: {
        var r = 300; var _ = posRev;
        for (var i = 0; i < nodeCount; i++) {
            var p = posOf(i);
            r = Math.max(r, Math.abs(p.x) + nr, Math.abs(p.y) + nr, Math.abs(p.z) + nr);
        }
        return Math.round(r * 1.2);
    }
    function selectedPos() { return selected >= 0 ? posOf(selected) : Qt.vector3d(0, 0, 0); }
    function setSelectedAxis(axis, v) {
        if (selected < 0) return;
        var p = posOf(selected);
        var np = Qt.vector3d(axis === "x" ? v : p.x, axis === "y" ? v : p.y, axis === "z" ? v : p.z);
        var m = {}; for (var k in posOverride) m[k] = posOverride[k];
        m[selected] = np; posOverride = m; posRev++;
        // In the flat layout, X/Z mirror back to the 2D model (Y is a 3D-only lift).
        if (!cuboidMode && ctl && axis !== "y") ctl.moveVertex(selected, np.x, np.z);
    }
    // Drop the selected node's pin (back to the cuboid / flat position).
    function clearSelectedPos() {
        if (selected < 0 || posOverride[selected] === undefined) return;
        var m = {}; for (var k in posOverride) if (+k !== selected) m[k] = posOverride[k];
        posOverride = m; posRev++;
    }

    // Persist the scalar style + role colours, the 3D arrangement (cuboid layout
    // and user-pinned positions), and per-node colour overrides, so the exact 3D
    // view is restored from a saved document / the last session.
    function _vecMap(m) { var o = {}; for (var k in m) { var v = m[k]; o[k] = [v.x, v.y, v.z]; } return o; }
    function _plainMap(m) { var o = {}; for (var k in m) o[k] = m[k]; return o; }
    function exportStyle3D() {
        function cs(c) { return c.a > 0 ? "" + c : ""; }
        return {
            nodeScale: nodeScale, edgeScale: edgeScale, arrowScale: arrowScale,
            nodeLabelSize: nodeLabelSize, edgeLabelSize: edgeLabelSize,
            edgeStyle: edge3dStyle, curvature: curvature3d, edgeOpacity: edgeOpacity, showAxes: showAxes3d,
            animEnabled: animEnabled, tokenStyle: tokenStyle, tokenScale: tokenScale,
            node: cs(nodeFillOverride), edge: cs(edgeOverride), label: cs(labelOverride),
            source: cs(srcOverride), frontier: cs(frontierOverride),
            current: cs(currentOverride), settled: cs(settledOverride),
            treeEdge: cs(treeEdgeOverride), activeEdge: cs(activeEdgeOverride), pathEdge: cs(pathEdgeOverride),
            tokenColor: cs(tokenOverride),
            cuboidMode: cuboidMode, cuboidPos: _vecMap(cuboidPos), posOverride: _vecMap(posOverride),
            cuboidW: cuboidW, cuboidH: cuboidH, cuboidD: cuboidD,
            globeMode: globeMode, globePos: _vecMap(globePos), globeOpacity: globeOpacity,
            nodeColors: _plainMap(nodeColors), edgeCurve: _plainMap(edgeCurve)
        };
    }
    function importStyle3D(s) {
        if (!s) return;
        if (s.nodeScale !== undefined) nodeScale = s.nodeScale;
        if (s.edgeScale !== undefined) edgeScale = s.edgeScale;
        if (s.arrowScale !== undefined) arrowScale = s.arrowScale;
        if (s.nodeLabelSize !== undefined) nodeLabelSize = s.nodeLabelSize;
        if (s.edgeLabelSize !== undefined) edgeLabelSize = s.edgeLabelSize;
        if (s.edgeStyle !== undefined) edge3dStyle = s.edgeStyle;
        if (s.curvature !== undefined) curvature3d = s.curvature;
        if (s.edgeOpacity !== undefined) edgeOpacity = s.edgeOpacity;
        if (s.showAxes !== undefined) showAxes3d = s.showAxes;
        if (s.animEnabled !== undefined) animEnabled = s.animEnabled;
        if (s.tokenStyle !== undefined) tokenStyle = s.tokenStyle;
        if (s.tokenScale !== undefined) tokenScale = s.tokenScale;
        function col(v) { return (v && v.length) ? v : "transparent"; }
        if (s.node !== undefined) nodeFillOverride = col(s.node);
        if (s.edge !== undefined) edgeOverride = col(s.edge);
        if (s.label !== undefined) labelOverride = col(s.label);
        if (s.source !== undefined) srcOverride = col(s.source);
        if (s.frontier !== undefined) frontierOverride = col(s.frontier);
        if (s.current !== undefined) currentOverride = col(s.current);
        if (s.settled !== undefined) settledOverride = col(s.settled);
        if (s.treeEdge !== undefined) treeEdgeOverride = col(s.treeEdge);
        if (s.activeEdge !== undefined) activeEdgeOverride = col(s.activeEdge);
        if (s.pathEdge !== undefined) pathEdgeOverride = col(s.pathEdge);
        if (s.tokenColor !== undefined) tokenOverride = col(s.tokenColor);
        function vmap(o) { var m = {}; for (var k in o) { var a = o[k]; m[k] = Qt.vector3d(a[0], a[1], a[2]); } return m; }
        if (s.cuboidW !== undefined) cuboidW = s.cuboidW;
        if (s.cuboidH !== undefined) cuboidH = s.cuboidH;
        if (s.cuboidD !== undefined) cuboidD = s.cuboidD;
        if (s.globeOpacity !== undefined) globeOpacity = s.globeOpacity;
        // The LAYOUT state (globe / cuboid modes + their positions + user pins) is
        // AUTHORITATIVE to the document: an absent key resets to the flat default,
        // so loading a new file never inherits the previous doc's globe/cuboid.
        // (exportStyle3D always writes these, so saved docs round-trip exactly.)
        cuboidPos   = (s.cuboidPos   !== undefined) ? vmap(s.cuboidPos)   : ({});
        posOverride = (s.posOverride !== undefined) ? vmap(s.posOverride) : ({});
        cuboidMode  = (s.cuboidMode  !== undefined) ? s.cuboidMode : false;
        globePos    = (s.globePos    !== undefined) ? vmap(s.globePos) : ({});
        globeMode   = (s.globeMode   !== undefined) ? s.globeMode : false;
        // Globe requested but no positions carried (e.g. a sample that just sets
        // globeMode): compute them from the nodes' lon/lat now. Decouples the data
        // file from the radius constant and recovers a restored globe session.
        if (globeMode && Object.keys(globePos).length === 0 && nodeCount > 0) layoutGlobe(false);
        if (s.nodeColors !== undefined) { var nc = {}; for (var k2 in s.nodeColors) nc[k2] = s.nodeColors[k2]; nodeColors = nc; }
        if (s.edgeCurve !== undefined) { var ec = {}; for (var k3 in s.edgeCurve) ec[k3] = s.edgeCurve[k3]; edgeCurve = ec; }
        cuboidRelay.stop();   // don't let the ratio writes above re-lay over the restored cuboidPos
        styleRev++; posRev++;
    }

    // Cached document snapshots (nodeList/edgeList/nodeArr/edgeArr, nodeCount,
    // edgeCount, directed, vstates, vdists, edgeStateList + refreshEdgeStates) are
    // inherited from GraphViewBase.
    // Above this size, drop per-edge/per-node text labels (unreadable + costly).
    readonly property bool dense: nodeCount > 60 || edgeCount > 100

    // Node sphere radius (world units) — shrinks as the graph grows, matching 2D.
    readonly property int nr: {
        var n = nodeCount;
        if (n <= 40) return 22;
        return Math.max(7, Math.min(22, Math.round(22 * Math.sqrt(40 / n))));
    }
    readonly property int labelFont: Math.max(9, Math.min(16, Math.round(nr * 0.8)))
    // Effective sphere radius actually drawn (the node-size slider scales it).
    // Edge trims and label offsets must use this, else they leave a gap / overlap.
    readonly property real nrEff: nr * nodeScale

    // --- cuboid layout (3D-view-local) ---
    // A genuinely-3D arrangement: the 2D model only has x,y, so the cuboid lives
    // here as a per-vertex override (id -> vector3d). When active, posOf returns
    // it instead of the flat x,y mapping; the 2D view is untouched. `posRev` bumps
    // to re-evaluate posOf-based bindings after a cuboid (re)layout or drag.
    property bool cuboidMode: false
    property var cuboidPos: ({})     // id -> vector3d while cuboidMode
    // Target shape of the cuboid lattice as a width:height:depth (X:Y:Z) ratio.
    // 1:1:1 is the default cube-like packing; the View-Mode sliders change these and
    // re-lay the box. Changing one re-lays (debounced) while cuboid mode is active.
    property real cuboidW: 1
    property real cuboidH: 1
    property real cuboidD: 1
    onCuboidWChanged: if (cuboidMode) cuboidRelay.restart()
    onCuboidHChanged: if (cuboidMode) cuboidRelay.restart()
    onCuboidDChanged: if (cuboidMode) cuboidRelay.restart()
    Timer { id: cuboidRelay; interval: 120; onTriggered: if (root.cuboidMode) root.layoutCuboid() }

    // --- globe layout (3D-view-local) ---
    // Airline-map mode: each node carries geographic coordinates in its flat
    // x,y (x = longitude, y = latitude degrees); globe mode maps them onto the
    // surface of a sphere of radius `globeRadius`. Same override shape as the
    // cuboid: posOf returns globePos[id] while globeMode, the 2D model is untouched.
    property bool globeMode: false
    property var globePos: ({})      // id -> vector3d while globeMode
    // One-time guard: the grid / origin axes default OFF the FIRST time Globe is
    // shown (they cut through the sphere), but we must not keep clobbering the
    // user's choice. Once applied (or once a restored doc defined the state),
    // re-entering Globe keeps whatever grid / axes the user last set.
    property bool _globeViewDefaulted: false
    // Sphere radius in world units, sized so a few-dozen cities frame well and the
    // city spheres (nr) read clearly against it.
    readonly property real globeRadius: Math.max(260, nr * 18)
    // Earth opacity (0.1 opaque-ish … 1). Below 1 the sphere is translucent so cities
    // (and routes) on the FAR side show through, tinted by the ocean colour.
    property real globeOpacity: 0.65
    // `applyViewDefaults` turns the grid / axes off for a clean sphere. Defaults
    // to "only the first time" so an explicit user toggle survives a round-trip
    // to another layout and back; restore passes false so a saved doc's grid /
    // axes state is honoured.
    function layoutGlobe(applyViewDefaults) {
        if (applyViewDefaults === undefined) applyViewDefaults = !_globeViewDefaulted;
        var n = nodeCount, m = {}, R = globeRadius, D = Math.PI / 180;
        for (var i = 0; i < n; i++) {
            var nd = nodeArr[i];
            var lon = (nd ? nd.x : 0) * D, lat = (nd ? nd.y : 0) * D;
            var cl = Math.cos(lat);
            m[i] = Qt.vector3d(R * cl * Math.cos(lon), R * Math.sin(lat), R * cl * Math.sin(lon));
        }
        globePos = m; globeMode = true;
        cuboidPos = ({}); cuboidMode = false; posOverride = ({}); posRev++;   // fresh globe: drop pins/cuboid
        if (applyViewDefaults) { showGrid3d = false; showAxes3d = false; }   // the y=0 grid / origin axes cut through the sphere
        _globeViewDefaulted = true;
        Qt.callLater(fit);
    }
    function clearGlobe() {
        if (!globeMode) return;
        globePos = ({}); globeMode = false; posRev++;
        Qt.callLater(fit);
    }
    // User-pinned 3D positions (id -> vector3d), set by dragging a node or the
    // Selection X/Y/Z sliders. Highest priority in posOf; cleared by a re-layout.
    property var posOverride: ({})
    property int posRev: 0
    function clearPosOverride() { posOverride = ({}); posRev++; }
    // Grid dimensions (nx·ny·nz ≥ n) with side counts following the
    // cuboidW:cuboidH:cuboidD ratio (1:1:1 ⇒ cube-like), then the i-th centred
    // lattice cell (fills x, then y, then z).
    function gridDims(n) {
        var rw = Math.max(0.1, cuboidW), rh = Math.max(0.1, cuboidH), rd = Math.max(0.1, cuboidD);
        var k = Math.cbrt(Math.max(1, n) / (rw * rh * rd));
        var nx = Math.max(1, Math.round(k * rw));
        var ny = Math.max(1, Math.round(k * rh));
        var nz = Math.max(1, Math.round(k * rd));
        while (nx * ny * nz < n) nz++;     // guarantee capacity (absorb rounding in depth)
        return { nx: nx, ny: ny, nz: nz };
    }
    function seedPos(i, n) {
        var d = gridDims(n), step = nr * 4;
        var ix = i % d.nx;
        var iy = Math.floor(i / d.nx) % d.ny;
        var iz = Math.floor(i / (d.nx * d.ny));
        return Qt.vector3d((ix - (d.nx - 1) / 2) * step,
                           (iy - (d.ny - 1) / 2) * step,
                           (iz - (d.nz - 1) / 2) * step);
    }
    // Re-lay the whole cuboid lattice. `refit` reframes the camera — wanted for an
    // explicit "Cuboid" layout, but NOT for an incremental add/remove (that would
    // make the viewport jump/zoom under the user mid-edit).
    function layoutCuboid(refit) {
        if (refit === undefined) refit = true;
        var n = nodeCount, m = {};
        for (var i = 0; i < n; i++) m[i] = seedPos(i, n);
        cuboidPos = m; cuboidMode = true; posOverride = ({}); posRev++;   // fresh lattice: drop pins
        if (refit) Qt.callLater(fit);
    }
    function clearCuboid() {
        cuboidPos = ({}); cuboidMode = false; posOverride = ({}); posRev++;
        Qt.callLater(fit);
    }
    // Free-style: hand layout control to the user. Unlike clearCuboid(), it KEEPS the
    // current positions — if we're leaving the cuboid, each node is pinned where the
    // lattice put it so nothing jumps — and it does NOT reframe the camera. From a
    // flat layout it's a no-op (positions already free; existing pins kept). After
    // this, drag a node to move it and double-click empty ground to add one.
    function freeStyle() {
        if (cuboidMode || globeMode) {
            var src = cuboidMode ? cuboidPos : globePos;
            var m = {}; for (var k in posOverride) m[k] = posOverride[k];
            for (var i = 0; i < nodeCount; i++)
                if (m[i] === undefined && src[i] !== undefined) m[i] = src[i];
            posOverride = m;
            cuboidPos = ({}); cuboidMode = false;
            globePos = ({}); globeMode = false;
            posRev++;
        }
    }
    // Lazily fill cuboid positions only for nodes that don't have one yet (e.g.
    // vertices added while this view was hidden). Unlike layoutCuboid(), it never
    // regenerates the existing arrangement or drops user pins — so a plain
    // hide/show (or a load that restored a saved cuboidPos) leaves the layout
    // exactly as it was.
    function ensureCuboid() {
        var n = nodeCount, o = {}, changed = false;
        for (var k in cuboidPos) o[k] = cuboidPos[k];
        for (var i = 0; i < n; i++)
            if (o[i] === undefined) { o[i] = seedPos(i, n); changed = true; }
        if (changed) { cuboidPos = o; posRev++; }
    }

    // World position of a vertex: a user pin wins, then the cuboid override, else
    // its 2D (x,y) laid flat on the XZ plane.
    function posOf(id) {
        var o = posOverride[id]; if (o !== undefined) return o;
        if (cuboidMode) { var c = cuboidPos[id]; if (c !== undefined) return c; }
        if (globeMode) { var g = globePos[id]; if (g !== undefined) return g; }
        var n = nodeArr[id];
        return n ? Qt.vector3d(n.x, 0, n.y) : Qt.vector3d(0, 0, 0);
    }

    // Index of the active edge (animFrom <-> animTo) so the token picks up any
    // per-edge curve override + stored orientation; -1 if not found.
    function activeEdgeIdx3d() {
        var es = edgeArr;
        for (var i = 0; i < es.length; i++)
            if ((es[i].from === animFrom && es[i].to === animTo)
                || (es[i].from === animTo && es[i].to === animFrom)) return i;
        return -1;
    }

    // Sample the active edge's RENDERED 3D curve at UI progress uiT (0..1),
    // travelling animFrom -> animTo. Mirrors edgeXform's quadratic bezier (trimmed
    // endpoints + perpendicular/radial control) so the token rides the same path a
    // curved edge draws. The tip is backed off the destination rim by ~the cone's
    // half-height. Returns { pos, dir } (dir normalised) or null.
    function token3dSample(uiT) {
        if (animFrom < 0 || animTo < 0) return null;
        var idx = activeEdgeIdx3d();
        var ed = (idx >= 0) ? edgeArr[idx] : null;
        var fromId = ed ? ed.from : animFrom, toId = ed ? ed.to : animTo;
        var rev = ed ? (ed.from !== animFrom) : false;   // traversal opposite to storage
        var a0 = posOf(fromId), b0 = posOf(toId);
        var d = b0.minus(a0), L = d.length();
        if (L < 1) return null;
        var dn = d.times(1 / L);
        var a = a0.plus(dn.times(nrEff));                // trimmed to rims (as edgeXform)
        var b = b0.minus(dn.times(nrEff));
        var bow = (idx >= 0 && edgeCurve[idx] !== undefined) ? edgeCurve[idx]
                : (edge3dStyle === "curved" ? curvature3d : 0);
        var curved = globeMode || Math.abs(bow) > 0.001;
        var ctrl = null;
        if (globeMode) {
            var mid = a.plus(b).times(0.5);
            var rad = mid.length() > 1e-3 ? mid.times(1 / mid.length()) : Qt.vector3d(0, 1, 0);
            ctrl = mid.plus(rad.times(L * 0.45));
        } else if (curved) {
            var up = Qt.vector3d(0, 1, 0);
            var perp = dn.crossProduct(up);
            if (perp.length() < 1e-3) perp = dn.crossProduct(Qt.vector3d(1, 0, 0));
            perp = perp.normalized();
            ctrl = a.plus(b).times(0.5).plus(perp.times(bow * L * 0.5));
        }
        // Back the tip off the destination by ~the cone half-height (world units).
        var coneHalf = nrEff * 1.3 * tokenScale;
        var tMax = Math.max(0.02, 1 - coneHalf / L);
        var tt0 = Math.max(0, Math.min(1, uiT)) * tMax;
        var tt = rev ? (1 - tt0) : tt0;                  // param along stored edge
        var pos, dir;
        if (curved) {
            var it = 1 - tt;
            pos = a.times(it * it).plus(ctrl.times(2 * it * tt)).plus(b.times(tt * tt));
            dir = ctrl.minus(a).times(2 * it).plus(b.minus(ctrl).times(2 * tt));
        } else {
            pos = a.times(1 - tt).plus(b.times(tt));
            dir = b.minus(a);
        }
        if (rev) dir = dir.times(-1);                    // heading along animFrom -> animTo
        var dl = dir.length();
        return { pos: pos, dir: dl > 1e-4 ? dir.times(1 / dl) : Qt.vector3d(0, 1, 0) };
    }

    // ---- GPU instancing (LOD phase 3) ---------------------------------------
    // All node spheres / edge cylinders / arrow cones render as one instanced Model
    // each, filled from a flat per-instance array (position, scale, rotation, colour)
    // built here and handed to the C++ GraphInstanceTable. Build/add/remove/clear are
    // cheap buffer updates — no Model (delegate) per element, so large graphs stay
    // responsive. Rebuilt (O(n), one pass) from the change hooks below.
    // Pack per-node instance data (position, uniform scale, identity rotation, colour)
    // into one flat array for the GPU instance table. O(n), one pass, no delegates.
    function rebuildNodeInstances() {
        if (!ctl || !visible) { nodeInst.setEntries([]); return; }
        var n = nodeCount, s = nrEff / 50, flat = [];
        for (var i = 0; i < n; i++) {
            var p = posOf(i);
            var st = vstateAt(i);   // lagged: destination holds prior colour until arrival
            // Node keeps its own state/painted colour; selection is shown by the
            // translucent halo pass below (so the base colour stays readable).
            // nodeColors holds colour STRINGS (so they serialise/round-trip); the
            // instance buffer needs numeric r/g/b/a, so convert via Qt.color().
            var col = st === 1 ? frontierEff
                    : st === 2 ? currentEff
                    : st === 3 ? settledEff
                    : (nodeColors[i] !== undefined ? Qt.color(nodeColors[i]) : nodeFillEff);
            flat.push(p.x, p.y, p.z, s, s, s, 1, 0, 0, 0, col.r, col.g, col.b, col.a);
        }
        nodeInst.setEntries(flat);
    }
    // Highlight pass: a larger, translucent sphere around each selected node (accent)
    // and the current node (its state colour), standing in for the old emissive glow
    // / pulse. Usually a handful of instances, so trivially cheap.
    function rebuildSelInstances() {
        if (!ctl || !visible) { selInst.setEntries([]); return; }
        var n = nodeCount, s = nrEff / 50 * 1.5, flat = [];
        for (var i = 0; i < n; i++) {
            var st = vstateAt(i);
            var sel = isSel(i);
            if (!sel && st !== 2) continue;                 // only selected / current
            var p = posOf(i), col = sel ? colSelect : currentEff;
            flat.push(p.x, p.y, p.z, s, s, s, 1, 0, 0, 0, col.r, col.g, col.b, 0.35);
        }
        selInst.setEntries(flat);
    }
    // Pack per-edge instance data: a cylinder per shaft segment (one for straight,
    // several for curved) + a cone per directed arrowhead. For a large graph this
    // (edgeXform × up to edgeSegs per edge) is the dominant GUI-thread cost on load,
    // so when the load gate is up we build it in BATCHES on a timer — yielding to the
    // event loop between batches so the UI stays live (spinner animates, no "not
    // responding"), and the edges reveal progressively. Interactive rebuilds (small,
    // or while not loading) stay synchronous.
    property var _eflat: []
    property var _aflat: []
    property int _edgeIdx: 0
    readonly property bool building: edgeBuild.running
    function _appendEdges(from, to) {
        var es = edgeArr, asz = Math.max(6, nr * 0.3) * arrowScale;
        for (var j = from; j < to; j++) {
            var ed = es[j];
            var ev = edgeXform(ed.from, ed.to, j);
            if (!ev) continue;
            var st = edgeStateList.length > j ? edgeStateList[j] : 0;
            var selE = isEdgeSel(j);
            var idle = (st === 0 && !selE);   // not part of a run / not selected
            var col = st === 3 ? pathEdgeEff : st === 2 ? activeEdgeEff : st === 1 ? treeEdgeEff
                    : selE ? colSelect : edgeEff;
            // Idle edges: thin + translucent so a dense graph reads as a faint web and
            // the nodes + highlighted (run/selected/path) edges stand out. Highlighted
            // edges stay thick and fully opaque.
            var thick = ((st === 3) ? 3.2 : ((st === 1 || st === 2) ? 2.6 : (selE ? 2.8 : 1.0))) * edgeScale;
            var ea = idle ? edgeOpacity : col.a;
            for (var s = 0; s < ev.segs.length; s++) {
                var sg = ev.segs[s], q = sg.quat;
                _eflat.push(sg.mid.x, sg.mid.y, sg.mid.z, thick / 50, sg.len / 100, thick / 50,
                            q.scalar, q.x, q.y, q.z, col.r, col.g, col.b, ea);
            }
            if (directed) {
                var hq = ev.headQuat;
                _aflat.push(ev.headPos.x, ev.headPos.y, ev.headPos.z, asz / 50, headLen / 100, asz / 50,
                            hq.scalar, hq.x, hq.y, hq.z, col.r, col.g, col.b, ea);
            }
        }
    }
    Timer {
        id: edgeBuild; interval: 16; repeat: true
        onTriggered: {
            var E = root.edgeArr.length;
            var end = Math.min(E, root._edgeIdx + 1200);
            root._appendEdges(root._edgeIdx, end);
            root._edgeIdx = end;
            edgeInst.setEntries(root._eflat);
            arrowInst.setEntries(root._aflat);
            root.lastRebuildMs = Date.now();
            if (end >= E) edgeBuild.stop();
        }
    }
    function rebuildEdgeInstances() {
        edgeBuild.stop();
        if (!ctl || !visible) { edgeInst.setEntries([]); arrowInst.setEntries([]); return; }
        _eflat = []; _aflat = []; _edgeIdx = 0;
        var E = edgeArr.length;
        if (preparing && E > 1200) { edgeBuild.start(); return; }   // progressive, non-blocking
        _appendEdges(0, E);
        edgeInst.setEntries(_eflat);
        arrowInst.setEntries(_aflat);
    }
    function rebuildInstances() { rebuildNodeInstances(); rebuildEdgeInstances(); rebuildSelInstances(); lastRebuildMs = Date.now(); }

    // Quaternion rotating +Y (the default axis of #Cylinder / #Cone) onto `dn`.
    function quatFromYTo(dn) {
        var y = Qt.vector3d(0, 1, 0);
        var dot = Math.max(-1, Math.min(1, y.dotProduct(dn)));
        var axis = y.crossProduct(dn);
        if (axis.length() < 1e-6)
            return dot > 0 ? Qt.quaternion(1, 0, 0, 0) : Qt.quaternion(0, 0, 1, 0);
        axis = axis.normalized();
        var ang = Math.acos(dot), s = Math.sin(ang / 2);
        return Qt.quaternion(Math.cos(ang / 2), axis.x * s, axis.y * s, axis.z * s);
    }

    // Edge geometry: a shaft (one segment when straight, several sampled segments
    // when curved), the arrowhead pose, and the label spot. Curved edges bow along
    // a perpendicular so they arc clear of the straight chord.
    readonly property int edgeSegs: edgeCount > 60 ? 10 : 20
    function edgeXform(fromId, toId, idx) {
        var a0 = posOf(fromId), b0 = posOf(toId);
        var d = b0.minus(a0), L = d.length();
        if (L < 1) return null;
        var dn = d.times(1 / L);
        var a = a0.plus(dn.times(nrEff));              // trimmed to the node rims
        var b = b0.minus(dn.times(nrEff));
        // A per-edge curve override (Selection "Curve" slider) wins; else the global style.
        var bow = (idx !== undefined && edgeCurve[idx] !== undefined) ? edgeCurve[idx]
                : (edge3dStyle === "curved" ? curvature3d : 0);
        // On the globe, every route arcs outward (radially) above the surface, like a
        // flight-path map — straight chords would sink inside the opaque Earth.
        var curved = globeMode || Math.abs(bow) > 0.001;
        var pts;
        if (globeMode) {
            // Radial bow: push the chord midpoint out from the globe centre (origin).
            // Longer routes arc higher so they clear the surface and read distinctly.
            var mid = a.plus(b).times(0.5);
            var rad = mid.length() > 1e-3 ? mid.times(1 / mid.length()) : Qt.vector3d(0, 1, 0);
            var ctrl = mid.plus(rad.times(L * 0.45));
            var K = edgeSegs; pts = [];
            for (var gi = 0; gi <= K; gi++) {
                var gt = gi / K, git = 1 - gt;
                pts.push(a.times(git * git).plus(ctrl.times(2 * git * gt)).plus(b.times(gt * gt)));
            }
        } else if (curved) {
            // Control point bowed perpendicular to the edge (prefer the up axis).
            var up = Qt.vector3d(0, 1, 0);
            var perp = dn.crossProduct(up);
            if (perp.length() < 1e-3) perp = dn.crossProduct(Qt.vector3d(1, 0, 0));
            perp = perp.normalized();
            var ctrl = a.plus(b).times(0.5).plus(perp.times(bow * L * 0.5));
            var bEnd = directed ? b : b;   // trim happens via the last segment below
            var K = edgeSegs; pts = [];
            for (var i = 0; i <= K; i++) {
                var t = i / K, it = 1 - t;
                pts.push(a.times(it * it).plus(ctrl.times(2 * it * t)).plus(b.times(t * t)));
            }
        } else {
            var shaftEnd = directed ? b.minus(dn.times(headLen)) : b;
            pts = [a, shaftEnd];
        }
        // Build cylinder segments between consecutive points.
        var segs = [];
        for (var j = 0; j < pts.length - 1; j++) {
            var p1 = pts[j], p2 = pts[j + 1], seg = p2.minus(p1), sl = Math.max(0.001, seg.length());
            segs.push({ mid: p1.plus(p2).times(0.5), quat: quatFromYTo(seg.times(1 / sl)), len: sl });
        }
        var last = pts.length - 1;
        var ld = pts[last].minus(pts[last - 1]); ld = ld.times(1 / Math.max(0.001, ld.length()));
        return {
            segs: segs,
            headPos: b.minus(dn.times(headLen / 2)),
            headQuat: quatFromYTo(curved ? ld : dn),
            labelPos: (curved ? pts[Math.floor(pts.length / 2)] : a.plus(b).times(0.5)).plus(Qt.vector3d(0, 12, 0))
        };
    }

    // --- billboard helpers (labels face the camera, constant on-screen size) ---
    function faceYaw(wx, wz) {
        return Math.atan2(camera.scenePosition.x - wx, camera.scenePosition.z - wz) * 180 / Math.PI;
    }
    readonly property real labelRef: 700
    function camDist(wp) { return camera.scenePosition.minus(wp).length(); }
    function labelScale(wp) { var s = camDist(wp) / labelRef; return Qt.vector3d(s, s, s); }

    // Frame the whole graph: pivot at the node centroid, back the camera off so
    // the layout's XZ bounding box fits both the vertical and horizontal FOV.
    function fit() {
        var n = nodeCount;
        var c, R;
        if (globeMode) {
            // The Earth is centred at the origin; frame the sphere itself (cities
            // cluster in the northern hemisphere, so their centroid is off-centre).
            // Extra room for the route arcs that rise above the surface.
            c = Qt.vector3d(0, 0, 0);
            R = globeRadius * 1.5 + nr;
        } else {
            c = Qt.vector3d(0, 0, 0);
            if (n > 0) {
                for (var i = 0; i < n; i++) c = c.plus(posOf(i));
                c = c.times(1 / n);
            }
            // Bounding-sphere framing: robust for both the flat layout and the cuboid
            // (which also spreads in Y), regardless of the camera tilt below.
            var hx = nr, hy = nr, hz = nr;
            for (var j = 0; j < n; j++) {
                var p = posOf(j).minus(c);
                hx = Math.max(hx, Math.abs(p.x) + nr);
                hy = Math.max(hy, Math.abs(p.y) + nr);
                hz = Math.max(hz, Math.abs(p.z) + nr);
            }
            R = Math.sqrt(hx * hx + hy * hy + hz * hz) + 30;   // + label headroom
        }
        var aDeg = 32, a = aDeg * Math.PI / 180;               // look down 32°
        var fov = (camera.fieldOfView > 0 ? camera.fieldOfView : 60) * Math.PI / 180;
        var tanV = Math.tan(fov / 2);
        var aspect = (view.width > 0 && view.height > 0) ? view.width / view.height : 1.6;
        var dist = Math.max(R / tanV, R / (tanV * aspect)) * 1.1;
        dist = Math.max(dist, 60);
        originNode.position = c;
        camera.position = Qt.vector3d(0, dist * Math.sin(a), dist * Math.cos(a));
        camera.eulerRotation = Qt.vector3d(-aDeg, 0, 0);
    }
    function zoomBy3D(f) {
        var p = camera.position, len = p.length();
        if (len < 1e-3) return;
        var nl = Math.max(30, Math.min(500000, len * f));
        camera.position = p.times(nl / len);
    }

    property string dragId: ""   // index (as string) of the node being dragged ("" = none)
    property var _grpStart: ({})  // id -> start posOf during a group drag
    property vector3d _dragAnchor: Qt.vector3d(0, 0, 0)   // ground hit at drag start
    // Rubber-band box-select (Shift-drag empty space); screen (view) coordinates.
    property bool band3d: false
    property real bx0: 0; property real by0: 0; property real bx1: 0; property real by1: 0

    // Node size feeds the edge-rim trim (nrEff); bump posRev so edge geometry
    // re-evaluates live as the size slider moves.
    onNodeScaleChanged: posRev++
    onEdgeScaleChanged: posRev++
    onArrowScaleChanged: posRev++
    onEdge3dStyleChanged: posRev++
    onCurvature3dChanged: posRev++
    onEdgeOpacityChanged: styleRev++
    Component.onCompleted: if (visible) { refreshEdgeStates(); rebuildInstances(); Qt.callLater(fit); }
    // Coalesce rebuilds: a single load bumps posRev + styleRev (+ graphChanged, cuboid
    // re-lay), each of which used to run a full O(n+e) rebuild synchronously — several
    // per load. Queue one deferred rebuild per event-loop turn instead.
    property bool _rebuildQueued: false
    // While the load gate is up (`preparing`), a single load fires many bumps across
    // several event-loop turns (applyDoc, applyViewFromCtl, cuboid re-lay, …). Qt.callLater
    // only coalesces within a turn, so that produced ~8 full O(n+e) rebuilds — seconds of
    // synchronous work. Debounce the whole burst into ONE rebuild. Outside a load, keep the
    // per-turn callLater so dragging stays responsive.
    Timer { id: rebuildDebounce; interval: 60; onTriggered: root.rebuildInstances() }
    function scheduleRebuild() {
        if (preparing) { rebuildDebounce.restart(); return; }
        if (root._rebuildQueued) return;
        root._rebuildQueued = true;
        Qt.callLater(function () { root._rebuildQueued = false; root.rebuildInstances(); });
    }
    // Recompute the instance buffers when positions / style / selection change.
    onPosRevChanged: scheduleRebuild()
    onStyleRevChanged: scheduleRebuild()
    onSelRevChanged: scheduleRebuild()
    onCanvasFullChanged: if (visible) Qt.callLater(fit)
    onWidthChanged: if (visible) Qt.callLater(fit)
    onHeightChanged: if (visible) Qt.callLater(fit)
    // Catch up when shown after edits happened while hidden: refresh state, keep
    // the cuboid lattice valid, and reframe once.
    onVisibleChanged: if (visible) { refreshEdgeStates(); rebuildInstances(); if (cuboidMode) ensureCuboid(); rampLabels(); Qt.callLater(fit); }
    // Repaint node colours when the lagged playback states change (step + arrival).
    onVisualStatesChanged: if (visible) scheduleRebuild()
    Connections {
        target: root.ctl
        enabled: root.visible          // hidden view does no per-change work
        // Keep edge highlight state current; in cuboid mode re-lay the lattice ONLY
        // when the vertex count changes (an added/removed vertex needs a slot).
        // Doing it on every change re-laid all nodes and bumped posRev, forcing the
        // whole scene to re-evaluate/re-render — which froze a large graph on an
        // edge edit. No per-edit camera auto-fit (use the Fit control to reframe).
        function onGraphChanged() {
            root.refreshEdgeStates();
            // Keep the cuboid lattice valid across edits WITHOUT reframing the camera
            // (an auto-fit here made the viewport jump/zoom on add/delete). On an add,
            // just fill the new slots (existing nodes stay put); on a remove (ids
            // reindex) re-lay, but never refit.
            if (root.cuboidMode && root.nodeCount > 0 && root.nodeCount !== root._lastNodeCount) {
                if (root.nodeCount > root._lastNodeCount) root.ensureCuboid();
                else root.layoutCuboid(false);
            }
            root._lastNodeCount = root.nodeCount;
            root.scheduleRebuild();                       // deferred + coalesced
        }
        function onCursorChanged() { root.refreshEdgeStates(); root.scheduleRebuild(); }
        function onPathChanged() { root.refreshEdgeStates(); }
    }

    View3D {
        id: view
        anchors.fill: parent
        camera: camera          // explicit active camera — required for mapFrom3DScene/mapTo3DScene
        environment: SceneEnvironment {
            clearColor: root.colBg
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
            InfiniteGrid { gridInterval: 50; visible: root.showGrid3d }
        }

        Node {
            id: originNode
            PerspectiveCamera { id: camera; clipFar: 200000 }
        }

        DirectionalLight { eulerRotation.x: -40; eulerRotation.y: -25 }
        DirectionalLight { eulerRotation.x: 15; eulerRotation.y: 160; brightness: 0.5 }

        // Transparent ground at y=0 (visual reference; node-drag XZ now comes from a
        // ray-plane math hit, not a pick — see groundHit).
        Model {
            source: "#Rectangle"
            objectName: "ground"
            pickable: false
            eulerRotation.x: -90
            scale: Qt.vector3d(400, 400, 1)
            materials: PrincipledMaterial {
                baseColor: Qt.rgba(0, 0, 0, 0)
                alphaMode: PrincipledMaterial.Blend
                lighting: PrincipledMaterial.NoLighting
            }
        }

        // X/Y/Z reference axes through the origin (red/green/blue) with tip cones
        // and billboarded labels — a spatial reference for orbiting / positioning.
        Node {
            visible: root.showAxes3d
            Repeater3D {
                model: [ { d: Qt.vector3d(1, 0, 0), c: "#ef4444", t: "X" },
                         { d: Qt.vector3d(0, 1, 0), c: "#22c55e", t: "Y" },
                         { d: Qt.vector3d(0, 0, 1), c: "#3b82f6", t: "Z" } ]
                delegate: Node {
                    id: ax
                    required property var modelData
                    readonly property vector3d dir: modelData.d
                    Model {   // axis line through the origin
                        source: "#Cylinder"; rotation: root.quatFromYTo(ax.dir)
                        scale: Qt.vector3d(0.03, 2 * root.posRange / 100, 0.03)
                        materials: PrincipledMaterial { baseColor: ax.modelData.c; lighting: PrincipledMaterial.NoLighting }
                    }
                    Model {   // +end tip cone
                        source: "#Cone"; position: ax.dir.times(root.posRange); rotation: root.quatFromYTo(ax.dir)
                        scale: Qt.vector3d(0.09, 0.14, 0.09)
                        materials: PrincipledMaterial { baseColor: ax.modelData.c; lighting: PrincipledMaterial.NoLighting }
                    }
                    Node {    // axis label (billboarded)
                        id: axLbl
                        position: ax.dir.times(root.posRange + 24)
                        eulerRotation.y: root.faceYaw(axLbl.position.x, axLbl.position.z)
                        scale: root.labelScale(axLbl.position)
                        Text { text: ax.modelData.t; color: ax.modelData.c; font.pixelSize: 22; font.bold: true }
                    }
                }
            }
        }

        // --- edges: one instanced cylinder (shaft segments) + one instanced cone
        // (directed arrowheads) for the whole graph. Packed by rebuildEdgeInstances().
        Model {
            source: "#Cylinder"
            instancing: GraphInstanceTable { id: edgeInst }
            // Blend so the per-instance alpha takes effect — idle edges render
            // translucent (see rebuildEdgeInstances) so a dense graph reads as a
            // faint web and the nodes / highlighted edges stand out.
            materials: PrincipledMaterial {
                baseColor: "white"; lighting: PrincipledMaterial.NoLighting
                alphaMode: PrincipledMaterial.Blend; cullMode: Material.NoCulling
            }
        }
        Model {
            source: "#Cone"
            visible: root.directed
            instancing: GraphInstanceTable { id: arrowInst }
            materials: PrincipledMaterial {
                baseColor: "white"; lighting: PrincipledMaterial.NoLighting
                alphaMode: PrincipledMaterial.Blend; cullMode: Material.NoCulling
            }
        }

        // --- edge weight labels: small graphs only (as with node labels). ---
        Repeater3D {
            model: (root.showLabels && root.edgeCount <= 120) ? Math.min(root.edgeCount, root.labelBudget) : 0
            delegate: Node {
                required property int index
                readonly property int ei: index
                readonly property var ed: root.edgeArr[ei]
                readonly property var ev: (root.posRev, ed ? root.edgeXform(ed.from, ed.to, ei) : null)
                visible: ev !== null && ed !== undefined
                position: ev ? ev.labelPos : Qt.vector3d(0, 0, 0)
                eulerRotation.y: ev ? root.faceYaw(ev.labelPos.x, ev.labelPos.z) : 0
                scale: ev ? root.labelScale(ev.labelPos) : Qt.vector3d(1, 1, 1)
                Text { text: ed ? ("" + ed.weight) : ""
                       color: root.labelEff; font.pixelSize: root.edgeLabelSize; font.bold: true }
            }
        }

        // --- source marker: a red flat disk around the chosen start vertex ---
        Model {
            source: "#Cylinder"
            visible: root.sourceVertex >= 0 && root.sourceVertex < root.nodeCount
            position: (root.posRev, (root.sourceVertex >= 0 && root.sourceVertex < root.nodeCount)
                      ? root.posOf(root.sourceVertex) : Qt.vector3d(0, 0, 0))
            scale: Qt.vector3d(root.nrEff * 1.5 / 50, 0.04, root.nrEff * 1.5 / 50)
            materials: PrincipledMaterial { baseColor: root.srcEff; lighting: PrincipledMaterial.NoLighting }
        }

        // --- add-edge pending source: an amber disk around the picked source node ---
        Model {
            source: "#Cylinder"
            visible: root.edgeMode && root.pendingSrc >= 0 && root.pendingSrc < root.nodeCount
            position: (root.posRev, (root.pendingSrc >= 0 && root.pendingSrc < root.nodeCount)
                      ? root.posOf(root.pendingSrc) : Qt.vector3d(0, 0, 0))
            scale: Qt.vector3d(root.nrEff * 1.7 / 50, 0.05, root.nrEff * 1.7 / 50)
            materials: PrincipledMaterial { baseColor: root.colActiveEdge; lighting: PrincipledMaterial.NoLighting }
        }

        // --- Earth: a plain ocean-blue sphere for the airline-map (globe) layout.
        // Sized just under the city radius so cities sit on the surface; #Sphere is
        // radius 50, so scale = globeRadius/50. Lit by the scene's directional lights.
        Model {
            source: "#Sphere"
            visible: root.globeMode
            scale: { var s = root.globeRadius / 50 * 0.985; return Qt.vector3d(s, s, s); }
            // Blend always on so the opacity slider works live; at α=1 it reads as a
            // solid ocean. Below 1, the near surface tints the far-side nodes showing
            // through it (transparent pass tests the opaque depth buffer).
            materials: PrincipledMaterial {
                baseColor: Qt.rgba(0.075, 0.278, 0.478, root.globeOpacity)   // ocean blue
                metalness: 0.0; roughness: 0.85
                alphaMode: PrincipledMaterial.Blend
            }
        }

        // --- nodes: one instanced sphere Model for the whole graph — scales to
        // thousands with a single draw call / no delegate per node. The per-instance
        // colour carries state (frontier/current/settled) and the painted/idle fill.
        // Packed by rebuildNodeInstances(). Labels: see below.
        Model {
            source: "#Sphere"
            instancing: GraphInstanceTable { id: nodeInst }
            materials: PrincipledMaterial { baseColor: "white"; metalness: 0.1; roughness: 0.5 }
        }
        // --- selection/current highlight: one instanced translucent sphere, a little
        // larger, only for selected + current nodes (see rebuildSelInstances). ---
        Model {
            source: "#Sphere"
            instancing: GraphInstanceTable { id: selInst }
            materials: PrincipledMaterial {
                baseColor: "white"; lighting: PrincipledMaterial.NoLighting
                alphaMode: PrincipledMaterial.Blend; cullMode: Material.NoCulling
            }
        }

        // --- travelling playback indicator (mirrors the 2D token): an arrow cone
        // glides the active edge (animFrom -> animTo) as tokenT animates 0..1,
        // pointing along travel. Straight-line path (good for the common straight
        // edges; curved edges read fine too). ---
        Node {
            id: token3d
            property bool active: root.animEnabled && root.tokenT < 1 && root.animFrom >= 0
                                  && root.animTo >= 0 && root.animFrom !== root.animTo
            // Sample the active edge's rendered curve (follows curved 3D edges).
            property var ts: (root.posRev, root.tokenT, root.animFrom, root.animTo, root.animEnabled,
                              active ? root.token3dSample(root.tokenT) : null)
            visible: active && ts !== null
            position: ts ? ts.pos : Qt.vector3d(0, 0, 0)
            rotation: ts ? root.quatFromYTo(ts.dir) : Qt.quaternion(1, 0, 0, 0)
            readonly property real ss: root.nrEff / 50 * root.tokenScale   // base instance scale
            // Arrow — a cone pointing +Y (= travel direction).
            Model {
                visible: root.tokenStyle === "chevron"
                source: "#Cone"
                scale: Qt.vector3d(token3d.ss * 0.75, token3d.ss * 1.3, token3d.ss * 0.75)
                materials: PrincipledMaterial { baseColor: root.tokenEff; lighting: PrincipledMaterial.NoLighting }
            }
            // Dot / comet head — a sphere.
            Model {
                visible: root.tokenStyle === "dot" || root.tokenStyle === "comet"
                source: "#Sphere"
                scale: Qt.vector3d(token3d.ss * 0.7, token3d.ss * 0.7, token3d.ss * 0.7)
                materials: PrincipledMaterial { baseColor: root.tokenEff; lighting: PrincipledMaterial.NoLighting }
            }
            // Comet tail — fading spheres trailing behind along -Y (travel dir).
            Repeater3D {
                model: root.tokenStyle === "comet" ? 3 : 0
                delegate: Model {
                    required property int index
                    source: "#Sphere"
                    position: Qt.vector3d(0, -(index + 1) * token3d.ss * 1.4, 0)
                    scale: { var k = token3d.ss * (0.5 - index * 0.12); return Qt.vector3d(k, k, k); }
                    opacity: 0.5 - index * 0.14
                    materials: PrincipledMaterial {
                        baseColor: root.tokenEff; lighting: PrincipledMaterial.NoLighting
                        alphaMode: PrincipledMaterial.Blend
                    }
                }
            }
        }

        // --- arrival pulse: a translucent sphere that blooms at the destination
        // when the token lands (animArrived). `pulseT` 0..1 scales up + fades. ---
        Node {
            id: pulse3d
            property real pulseT: 1
            visible: pulseT < 1 && root.animTo >= 0
            position: (root.posRev, root.animTo >= 0 ? root.posOf(root.animTo) : Qt.vector3d(0, 0, 0))
            NumberAnimation { id: pulse3dAnim; target: pulse3d; property: "pulseT"; from: 0; to: 1; duration: 420; easing.type: Easing.OutQuad }
            Connections { target: root; function onAnimArrived() { pulse3dAnim.restart(); } }
            Model {
                source: "#Sphere"
                scale: { var k = root.nrEff / 50 * (1.2 + pulse3d.pulseT * 1.1); return Qt.vector3d(k, k, k); }
                opacity: Math.max(0, 0.45 * (1 - pulse3d.pulseT))
                materials: PrincipledMaterial {
                    baseColor: root.currentEff; lighting: PrincipledMaterial.NoLighting
                    alphaMode: PrincipledMaterial.Blend; cullMode: Material.NoCulling
                }
            }
        }

        // --- node labels: only for small graphs (unreadable, and too many to
        // billboard per frame, on large ones). A Node per vertex is fine here. ---
        Repeater3D {
            model: (root.showLabels && root.nodeCount <= 120) ? Math.min(root.nodeCount, root.labelBudget) : 0
            delegate: Node {
                required property int index
                readonly property vector3d np: (root.posRev, root.posOf(index))
                // On the globe, lift the label radially OUT from the sphere centre so it
                // floats clear of the surface in every viewport (an upward +Y offset
                // would sink into the sphere for cities off the top). Flat/cuboid: +Y.
                position: root.globeMode
                          ? np.plus((np.length() > 1e-3 ? np.times(1 / np.length()) : Qt.vector3d(0, 1, 0))
                                    .times(root.nrEff + 22))
                          : np.plus(Qt.vector3d(0, root.nrEff + 20, 0))
                eulerRotation.y: root.faceYaw(np.x, np.z)
                scale: root.labelScale(position)
                Text { text: root.nodeArr[index] ? root.nodeArr[index].label : ""
                       color: root.labelEff; font.pixelSize: root.nodeLabelSize; font.bold: true }
            }
        }
    }

    OrbitCameraController {
        anchors.fill: view
        origin: originNode
        camera: camera
        enabled: root.dragId === "" && !root.band3d   // off while dragging / box-selecting
    }

    // Selection + node drag. Above the orbit controller: a press on a node grabs
    // (drag it on the ground plane); a press on empty space is rejected so the
    // orbit controller handles it. Dragging is locked while auto-playing.
    MouseArea {
        id: picker
        anchors.fill: view
        acceptedButtons: Qt.LeftButton
        preventStealing: true
        // Screen-space picking: project node/edge geometry to the view and test it
        // against the cursor, instead of ray-casting the scene. view.pickAll()
        // traverses every Model and, for a ray through a dense cuboid, returns dozens
        // of hits — which froze picking (e.g. add-edge) on large graphs. This is O(n)
        // with the plain arrays and mirrors the box-select projection.
        readonly property real pickR: 22    // node hit radius (screen px)
        function firstNode(mx, my) {
            var n = root.nodeCount, best = "", bestZ = 1e18, r2 = pickR * pickR;
            for (var i = 0; i < n; i++) {
                var sp = view.mapFrom3DScene(root.posOf(i));
                if (sp.z <= 0) continue;                       // behind the camera
                var dx = sp.x - mx, dy = sp.y - my;
                if (dx * dx + dy * dy <= r2 && sp.z < bestZ) { bestZ = sp.z; best = "" + i; }
            }
            return best;                                        // frontmost node under the cursor, or ""
        }
        function firstEdge(mx, my) {
            var es = root.edgeArr, E = es.length, best = -1, bestD = 8 * 8;
            for (var j = 0; j < E; j++) {
                var a = view.mapFrom3DScene(root.posOf(es[j].from));
                var b = view.mapFrom3DScene(root.posOf(es[j].to));
                if (a.z <= 0 || b.z <= 0) continue;
                var d = segDistSq(mx, my, a.x, a.y, b.x, b.y);
                if (d < bestD) { bestD = d; best = j; }
            }
            return best;
        }
        // Squared screen-space distance from point (px,py) to segment (ax,ay)-(bx,by).
        function segDistSq(px, py, ax, ay, bx, by) {
            var vx = bx - ax, vy = by - ay, wx = px - ax, wy = py - ay;
            var c1 = vx * wx + vy * wy;
            if (c1 <= 0) return wx * wx + wy * wy;
            var c2 = vx * vx + vy * vy;
            if (c2 <= c1) { var ex = px - bx, ey = py - by; return ex * ex + ey * ey; }
            var t = c1 / c2, dx = px - (ax + t * vx), dy = py - (ay + t * vy);
            return dx * dx + dy * dy;
        }
        // Intersect the camera ray through (mx,my) with the y=0 ground plane (for
        // node dragging). Two points along the ray -> direction -> plane hit.
        function groundHit(mx, my) {
            var p0 = view.mapTo3DScene(Qt.vector3d(mx, my, 100));
            var p1 = view.mapTo3DScene(Qt.vector3d(mx, my, 1000));
            var dir = p1.minus(p0);
            if (Math.abs(dir.y) < 1e-6) return null;
            var t = -p0.y / dir.y;
            return { scenePosition: p0.plus(dir.times(t)) };
        }
        onPressed: function (mouse) {
            root.interacted();
            var id = firstNode(mouse.x, mouse.y);
            // Add-edge mode: a node press picks source then target (no drag/orbit);
            // an empty press is ignored so the pending pick is kept.
            if (root.edgeMode) {
                if (id !== "" && !root.locked) root.connectTap(parseInt(id));
                mouse.accepted = (id !== "");
                return;
            }
            if (root.playing) { mouse.accepted = false; return; }   // locked while playing
            var shift = (mouse.modifiers & Qt.ShiftModifier) !== 0;
            if (id !== "") {
                var vid = parseInt(id);
                if (shift) { root.toggleSel(vid); mouse.accepted = true; return; }   // add/remove, no drag
                if (!root.isSel(vid)) root.selectOnly(vid);        // drag an unselected node -> select it alone
                if (root.locked) { mouse.accepted = true; return; }   // scene locked → select only, no drag
                root.dragId = id;
                var a = groundHit(mouse.x, mouse.y);
                root._dragAnchor = a ? a.scenePosition : Qt.vector3d(0, 0, 0);
                var snap = {}; for (var k in root.selectedSet) snap[k] = root.posOf(+k);
                root._grpStart = snap;
                if (!root.cuboidMode && root.ctl) root.ctl.beginEdit();
                mouse.accepted = true;
            } else {
                var eid = firstEdge(mouse.x, mouse.y);
                if (eid >= 0) {                      // clicked an edge tube
                    if (shift) root.toggleEdgeSel(eid); else root.selectEdgeOnly(eid);
                    mouse.accepted = true;
                } else if (shift) {
                    root.band3d = true; root.bx0 = root.bx1 = mouse.x; root.by0 = root.by1 = mouse.y;
                    mouse.accepted = true;           // box-select (orbit suppressed)
                } else {
                    mouse.accepted = false;          // let the orbit controller orbit
                }
            }
        }
        onPositionChanged: function (mouse) {
            if (root.band3d) { root.bx1 = mouse.x; root.by1 = mouse.y; return; }
            if (root.dragId === "" || !root.ctl) return;
            var hit = groundHit(mouse.x, mouse.y);
            if (!hit) return;
            var p = hit.scenePosition;
            var dx = p.x - root._dragAnchor.x, dz = p.z - root._dragAnchor.z;
            // Move every selected node by the ground-plane delta, keeping each node's
            // Y lift. Flat layout also mirrors X/Z back to the 2D model.
            var m = {}; for (var k in root.posOverride) m[k] = root.posOverride[k];
            for (var key in root._grpStart) {
                var s = root._grpStart[key];
                var np = Qt.vector3d(s.x + dx, s.y, s.z + dz);
                m[key] = np;
                if (!root.cuboidMode) root.ctl.moveVertex(+key, np.x, np.z);
            }
            root.posOverride = m; root.posRev++;
        }
        onReleased: function (mouse) {
            if (root.band3d) {
                root.band3d = false;
                var minx = Math.min(root.bx0, root.bx1), maxx = Math.max(root.bx0, root.bx1);
                var miny = Math.min(root.by0, root.by1), maxy = Math.max(root.by0, root.by1);
                if (Math.abs(root.bx1 - root.bx0) >= 3 || Math.abs(root.by1 - root.by0) >= 3) {
                    var m = {}; for (var k in root.selectedSet) m[k] = true;   // additive
                    var last = -1, inside = {};
                    for (var i = 0; i < root.nodeCount; i++) {
                        var sp = view.mapFrom3DScene(root.posOf(i));    // project to screen
                        if (sp.z > 0 && sp.x >= minx && sp.x <= maxx && sp.y >= miny && sp.y <= maxy) { m[i] = true; inside[i] = true; last = i; }
                    }
                    root.selectedSet = m; if (last >= 0) root.selected = last;
                    // Edges with BOTH endpoints in the box join the selection too.
                    var em = {}; for (var ke in root.selectedEdgeSet) em[ke] = true;
                    var es = root.edgeArr, E = es.length;
                    for (var j = 0; j < E; j++) if (inside[es[j].from] && inside[es[j].to]) em[j] = true;
                    root.selectedEdgeSet = em; root.selRev++;
                }
            }
            root.dragId = "";
            root.rebuildInstances();   // reflect any box-select highlight change
        }
    }

    // Right-button: a right-DRAG pans (slides the orbit pivot in the camera's screen
    // plane); a right-CLICK on a node deletes it (matches the 2D view).
    MouseArea {
        anchors.fill: view
        acceptedButtons: Qt.RightButton
        property real lastX: 0
        property real lastY: 0
        property real downX: 0
        property real downY: 0
        property bool movedPan: false
        property string hitAtPress: ""     // node under the cursor at press, captured BEFORE any pan
        onPressed: function (mouse) {
            root.interacted();
            lastX = mouse.x; lastY = mouse.y; downX = mouse.x; downY = mouse.y; movedPan = false;
            hitAtPress = picker.firstNode(mouse.x, mouse.y);   // which node (if any) this click is on
        }
        onPositionChanged: function (mouse) {
            var dx = mouse.x - lastX, dy = mouse.y - lastY;
            lastX = mouse.x; lastY = mouse.y;
            if (Math.hypot(mouse.x - downX, mouse.y - downY) > 4) movedPan = true;
            if (!movedPan) return;         // sub-threshold jitter: don't pan, so the clicked node stays put
            var dist = camera.position.length();
            var fov = (camera.fieldOfView > 0 ? camera.fieldOfView : 60) * Math.PI / 180;
            var k = 2 * dist * Math.tan(fov / 2) / Math.max(1, view.height);
            var mv = camera.right.times(-dx * k).plus(camera.up.times(dy * k));
            originNode.position = originNode.position.plus(mv);
        }
        onReleased: function (mouse) {
            if (movedPan) return;                                 // was a pan, not a click
            // Delete the node that was under the cursor AT PRESS (the scene may have
            // shifted; re-hit-testing at release could pick a different node).
            if (hitAtPress !== "" && root.ctl && !root.locked) root.ctl.removeVertex(+hitAtPress);
        }
    }

    WheelHandler {
        onWheel: function (e) { root.interacted(); root.zoomBy3D(e.angleDelta.y > 0 ? 1 / 1.12 : 1.12); }
    }

    // A plain single tap on empty space clears the selection (node + edge). Taps
    // on nodes/edges are grabbed by the picker, and orbit is a drag, so this only
    // fires for an empty tap. A double tap on empty ground ADDS a node there — the
    // 3D analogue of double-clicking the 2D canvas, so you don't have to hunt for
    // blank vertices dropped by "Add vertices".
    TapHandler {
        acceptedModifiers: Qt.NoModifier
        onSingleTapped: function (ep, button) { root.clearSel(); root.clearEdgeSel(); }
        onDoubleTapped: function (ep, button) {
            if (root.edgeMode || root.playing || root.locked || !root.ctl) return;
            if (picker.firstNode(ep.position.x, ep.position.y) !== "") return;   // on a node → ignore (not a blank spot)
            var g = picker.groundHit(ep.position.x, ep.position.y);
            if (!g) return;
            // posOf maps a flat node's (x,y) onto the XZ ground plane, so feed the
            // ground hit's X/Z back as the 2D coordinates.
            root.ctl.addVertex(g.scenePosition.x, g.scenePosition.z);
        }
    }

    // Canvas overlays (info pane, legend, tools pane, selection box) — Overlay3D.qml
    Overlay3D { view: root }

}
