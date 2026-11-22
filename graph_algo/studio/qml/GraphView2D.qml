pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import UiKit

// Renders the controller's graph and animates an algorithm run: vertices are
// coloured by playback state (idle / frontier / current / settled), the result
// tree and the current step's edge are highlighted, and Dijkstra distances show
// under the nodes. Nodes are draggable; Ctrl+wheel zooms, empty-drag pans.
GraphViewBase {
    id: gv
    clip: true

    // ctl + node/edge selection + document snapshots come from GraphViewBase.
    property color canvasBg: "transparent"
    property bool playing: false        // auto-play active → node dragging is locked
    property bool locked: false         // scene lock: all editing gestures disabled
    property bool canvasFull: false     // mirrors the window's full-screen state
    signal fullScreenToggleRequested()  // user asked to enter/leave full screen
    // Undo/redo route to the window's unified history (graph + view). canUndo/canRedo
    // are bound from Main; the edit-pane buttons emit these.
    signal undoRequested()
    signal redoRequested()
    property bool canUndo: false
    property bool canRedo: false
    signal lockToggleRequested()        // toolbar lock button → window flips editLocked
    property bool showGrid: true        // world-aligned background grid
    property bool showLegend: true      // on-canvas state legend (below the info pane)
    property bool showLabels: true      // node names + weight/distance chips
    property int sourceVertex: -1       // currently-selected start vertex (red ring)
    readonly property color gridMinor: Qt.rgba(Theme.panelBorder.r, Theme.panelBorder.g, Theme.panelBorder.b, 0.22)
    readonly property color gridMajor: Qt.rgba(Theme.panelBorder.r, Theme.panelBorder.g, Theme.panelBorder.b, 0.5)

    // ---- appearance / style (driven by the Style tab's Controls2D) ----
    property real nodeScale: 1.0        // node radius multiplier (0.5..2)
    property real edgeWidthScale: 1.0   // edge line-width multiplier (0.5..2)
    property real arrowScale: 1.0        // arrowhead size multiplier (0.3..2)
    property real labelScale: 1.0        // label / weight-chip font multiplier (0.5..2)
    property string edgeStyle: "curved"  // "curved" (auto-bow) | "straight"
    property real curvature: 1.0         // bow magnitude multiplier (0..2)

    // Colour roles live in GraphViewBase; feed it this view's theme defaults.
    // Overrides, *Eff, workingColor/styleRev/nodeColors and the colorForRole/
    // applyColor/paintRole/resetColors helpers are all inherited.
    defNodeFill: Theme.nodeFill
    defEdge: Theme.edge
    defLabel: Theme.labelText
    defSource: Theme.stSource
    defFrontier: Theme.stFrontier
    defCurrent: Theme.stCurrent
    defSettled: Theme.stSettled
    defToken: Theme.textPrimary        // indicator default: dark in light theme, light in dark

    // --- selection: a set of nodes (for group move + styling). `selected`
    // is the "primary" (last-touched) member the Style tab's sliders use; the set
    // drives the group drag and the highlight rings. selRev bumps bindings. ---
    // Node/edge selection (selected, selectedSet, selRev, selectedEdge,
    // selectedEdgeSet + is/toggle/clear helpers) are inherited from GraphViewBase;
    // the per-edge bend `edgeCurve` is 2D-specific and stays here.
    property var edgeCurve: ({})
    // One-line summary of the current selection for the on-canvas tip (overlay below):
    // a single node's label (+ distance after a run), a single edge's endpoints +
    // weight, or an N-nodes / M-edges count.
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
            return "Edge " + (a ? a.label : e.from) + ((ctl && ctl.directed) ? "  →  " : "  —  ")
                 + (b ? b.label : e.to) + "   ·   weight " + e.weight;
        }
        var parts = [];
        if (nS) parts.push(nS + " node" + (nS > 1 ? "s" : ""));
        if (eS) parts.push(eS + " edge" + (eS > 1 ? "s" : ""));
        return parts.join(" + ") + " selected";
    }
    // Curve of the primary selected edge (0 = auto/straight); the slider sets it
    // on every selected edge.
    function selectedEdgeCurve() { return (selectedEdge >= 0 && edgeCurve[selectedEdge] !== undefined) ? edgeCurve[selectedEdge] : 0; }
    function setSelectedEdgeCurve(v) {
        var ids = _edgeSelIds(); if (ids.length === 0) return;
        var m = {}; for (var k in edgeCurve) m[k] = edgeCurve[k];
        for (var i = 0; i < ids.length; i++) m[ids[i]] = v;
        edgeCurve = m; selRev++; styleRev++;
    }
    // Edge indices shift when edges are added/removed, so drop the (transient)
    // edge selection whenever the edge count changes (not on a mere node drag).
    readonly property int _edgeCountWatch: ctl ? ctl.edgeCount : 0
    on_EdgeCountWatchChanged: clearEdgeSel()

    // selectedNodeColor / applySelectedColor / clearSelectedColor are inherited.

    // Persist the scalar style + role colours (not the transient per-node map).
    function exportStyle() {
        function cs(c) { return c.a > 0 ? "" + c : ""; }
        return {
            nodeScale: nodeScale, edgeWidthScale: edgeWidthScale, arrowScale: arrowScale,
            labelScale: labelScale, edgeStyle: edgeStyle, curvature: curvature,
            animEnabled: animEnabled, tokenStyle: tokenStyle, tokenScale: tokenScale,
            node: cs(nodeFillOverride), edge: cs(edgeOverride), label: cs(labelOverride),
            source: cs(srcOverride), frontier: cs(frontierOverride),
            current: cs(currentOverride), settled: cs(settledOverride),
            tokenColor: cs(tokenOverride),
            nodeColors: (function () { var o = {}; for (var k in nodeColors) o[k] = nodeColors[k]; return o; })(),
            edgeCurve: (function () { var o = {}; for (var k in edgeCurve) o[k] = edgeCurve[k]; return o; })()
        };
    }
    function importStyle(s) {
        if (!s) return;
        if (s.nodeScale !== undefined) nodeScale = s.nodeScale;
        if (s.edgeWidthScale !== undefined) edgeWidthScale = s.edgeWidthScale;
        if (s.arrowScale !== undefined) arrowScale = s.arrowScale;
        if (s.labelScale !== undefined) labelScale = s.labelScale;
        if (s.edgeStyle !== undefined) edgeStyle = s.edgeStyle;
        if (s.curvature !== undefined) curvature = s.curvature;
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
        if (s.tokenColor !== undefined) tokenOverride = col(s.tokenColor);
        if (s.nodeColors !== undefined) { var nc = {}; for (var k in s.nodeColors) nc[k] = s.nodeColors[k]; nodeColors = nc; styleRev++; }
        if (s.edgeCurve !== undefined) { var ec = {}; for (var k2 in s.edgeCurve) ec[k2] = s.edgeCurve[k2]; edgeCurve = ec; styleRev++; }
    }

    // ---- draggable canvas panes (info / edit / zoom) ----
    property string docLabel: ""        // document name, bound from the window
    readonly property int paneH: 40     // uniform pane height
    readonly property int btnH: 28      // uniform button height
    readonly property color paneBg: Qt.rgba(Theme.panelBg.r, Theme.panelBg.g, Theme.panelBg.b, 0.9)
    // Persisted pane top-left positions; UNSET (<= -1e6) means "use the default
    // top-aligned layout". The window's Settings aliases these so a user-moved
    // pane returns to the same spot next session.
    readonly property real paneUnset: -1000000
    property real infoX: paneUnset; property real infoY: paneUnset
    property real editX: paneUnset; property real editY: paneUnset
    property real zoomX: paneUnset; property real zoomY: paneUnset
    function paneClamp(v, def, extent) {
        var p = (v <= -999999) ? def : v;
        return Math.max(0, Math.min(Math.max(0, extent), p));
    }
    signal realignRequested()           // window resets any panes it owns (run bar)
    // Reset every canvas pane to its default (top-aligned) position.
    function realign() {
        infoX = paneUnset; infoY = paneUnset;
        editX = paneUnset; editY = paneUnset;
        zoomX = paneUnset; zoomY = paneUnset;
        realignRequested();
    }

    // Drag grip for the panes is the shared Grip.qml component (host: gv).
    // Uniform pane button.
    component PaneBtn: UiButton { implicitHeight: gv.btnH }
    // Node radius shrinks as the graph grows, so large samples don't overlap
    // into an unreadable blob (small graphs keep the comfortable 22px).
    readonly property int nr: {
        var n = ctl ? ctl.nodeCount : 0;
        var base = (n <= 40) ? 22 : Math.max(7, Math.min(22, Math.round(22 * Math.sqrt(40 / n))));
        return Math.max(4, Math.round(base * nodeScale));
    }
    readonly property int labelFont: Math.max(6, Math.min(26, Math.round(nr * 0.72 * labelScale)))

    // Cache the model once per change. ctl.nodes / ctl.edges are C++ getters that
    // rebuild a fresh list every call, so reading them per-edge/per-chip caused
    // huge allocation churn. These re-evaluate once per graphChanged.
    // Gated on `visible`: while the 3D view is showing, this view is hidden and
    // must do no per-edit work — otherwise every edit rebuilds BOTH views' models
    // and delegates. Empty lists collapse all the Repeaters below to zero items.
    // nodeList/edgeList + the nodeArr/edgeArr JSON snapshots come from GraphViewBase.
    readonly property var posMap: {
        var m = ({}), ns = nodeArr, N = ns.length;
        for (var i = 0; i < N; i++) m[ns[i].id] = ns[i];
        return m;
    }

    // ---- viewport culling (LOD phase 1) -------------------------------------
    // For large graphs, only instantiate delegates for items inside the visible
    // world-rect, so the live scene scales with screen area, not graph size. Small
    // graphs keep the original count-based models and render in full (regression-safe).
    // The visible sets are recomputed explicitly (pan/zoom + structural changes),
    // never reactively on every graphChanged — so a drag (which fires graphChanged
    // per move) doesn't reassign the model array and destroy the grabbed delegate.
    readonly property bool culling: (ctl ? ctl.nodeCount : 0) > 400
    property bool dragging: false        // a node drag is in progress (freeze culling)
    readonly property real cellSize: Math.max(40, nr * 4)
    property var _grid: ({})             // "gx,gy" -> [nodeIndex,...]
    property var visibleNodeIdx: []      // node indices on screen (culling mode)
    property var visibleEdgeIdx: []      // edge indices with a visible endpoint
    // LOD phase 2: when too many items would be on screen at once (zoomed out),
    // show a single rasterized overview "satellite" image instead of live delegates.
    // Hysteresis (enter high, exit low) stops it flapping around the threshold.
    property bool overview: false
    onCullingChanged: if (!culling) { overview = false; visibleNodeIdx = []; visibleEdgeIdx = []; }
    // Layout bounding box (world coords, + margin) — the overview image's extent.
    readonly property var bbox: {
        var ns = nodeArr, N = ns.length; if (!N) return { x: 0, y: 0, w: 1, h: 1 };
        var minx = 1e9, miny = 1e9, maxx = -1e9, maxy = -1e9;
        for (var i = 0; i < N; i++) {
            var n = ns[i];
            if (n.x < minx) minx = n.x; if (n.x > maxx) maxx = n.x;
            if (n.y < miny) miny = n.y; if (n.y > maxy) maxy = n.y;
        }
        var m = nr * 2;
        return { x: minx - m, y: miny - m, w: (maxx - minx) + 2 * m, h: (maxy - miny) + 2 * m };
    }
    // Render the overview at a capped resolution; the content transform blows the
    // low-res image up over the world bbox (the "satellite" look).
    readonly property real ovScale: Math.min(1, 1200 / Math.max(1, Math.max(bbox.w, bbox.h)))
    readonly property int ovW: Math.max(1, Math.round(bbox.w * ovScale))
    readonly property int ovH: Math.max(1, Math.round(bbox.h * ovScale))
    Timer { id: cullTimer; interval: 30; repeat: false; onTriggered: { gv.rebuildGrid(); gv.recull(); } }
    onPanXChanged: if (gv.culling && !gv.dragging) cullTimer.restart()
    onPanYChanged: if (gv.culling && !gv.dragging) cullTimer.restart()
    onZoomChanged: if (gv.culling) cullTimer.restart()
    // (Re)build the spatial grid from current node positions — on load / add /
    // remove / relayout / drag-end, not during a drag.
    function rebuildGrid() {
        var g = ({}), ns = nodeArr, cs = cellSize, N = ns.length;
        for (var i = 0; i < N; i++) {
            var nd = ns[i];
            var k = Math.floor(nd.x / cs) + "," + Math.floor(nd.y / cs);
            if (g[k] === undefined) g[k] = [];
            g[k].push(i);
        }
        _grid = g;
    }
    // Visible rectangle in world (content) coordinates — inverse of the content
    // transform (see zoomAt), padded by one cell.
    function worldRect() {
        var ox = width / 2, oy = height / 2, m = cellSize;
        var x0 = ox + (0 - panX - ox) / zoom, x1 = ox + (width - panX - ox) / zoom;
        var y0 = oy + (0 - panY - oy) / zoom, y1 = oy + (height - panY - oy) / zoom;
        return { x0: Math.min(x0, x1) - m, y0: Math.min(y0, y1) - m,
                 x1: Math.max(x0, x1) + m, y1: Math.max(y0, y1) + m };
    }
    // Recompute the visible node/edge index sets (culling mode only). Skipped while
    // dragging so the model arrays — and thus the delegates — stay put.
    function recull() {
        if (!culling || dragging) return;
        var ns = nodeArr, cs = cellSize, r = worldRect(), out = [];
        var gx0 = Math.floor(r.x0 / cs), gx1 = Math.floor(r.x1 / cs);
        var gy0 = Math.floor(r.y0 / cs), gy1 = Math.floor(r.y1 / cs);
        for (var gx = gx0; gx <= gx1; gx++)
            for (var gy = gy0; gy <= gy1; gy++) {
                var arr = _grid[gx + "," + gy];
                if (arr === undefined) continue;
                for (var a = 0; a < arr.length; a++) {
                    var nd = ns[arr[a]];
                    if (nd && nd.x >= r.x0 && nd.x <= r.x1 && nd.y >= r.y0 && nd.y <= r.y1) out.push(arr[a]);
                }
            }
        out.sort(function (p, q) { return p - q; });   // stable order -> no needless delegate churn
        var vs = ({});
        for (var i = 0; i < out.length; i++) vs[ns[out[i]].id] = true;
        var es = edgeArr, eo = [], E = es.length;
        for (var j = 0; j < E; j++) if (vs[es[j].from] || vs[es[j].to]) eo.push(j);
        // Too much on screen to draw live? Switch to the overview raster (hysteresis:
        // enter at the high mark, leave only once well below it).
        var hiN = overview ? 400 : 650, hiE = overview ? 700 : 1100;
        overview = (out.length > hiN || eo.length > hiE);
        if (overview) { visibleNodeIdx = []; visibleEdgeIdx = []; }
        else { visibleNodeIdx = out; visibleEdgeIdx = eo; }
    }
    // vstates / vdists / edgeStateList + refreshEdgeStates come from GraphViewBase.
    readonly property int pathTarget: ctl ? ctl.pathTarget : -1

    // Progressive instantiation: creating thousands of node/edge delegates in
    // one go freezes the UI, so after a bulk load of a large graph we ramp
    // `renderCount` up in batches across event-loop ticks. Normally it stays
    // effectively unlimited, so interactive edits appear immediately.
    readonly property int unlimited: 1 << 30
    property int renderCount: unlimited
    readonly property int maxItems: Math.max(ctl ? ctl.edgeCount : 0, ctl ? ctl.nodeCount : 0)
    // True while the progressive ramp is still instantiating delegates — drives
    // the "Rendering…" indicator and gates Run/Play (see Main.qml).
    readonly property bool rendering: renderCount < maxItems
    // Beyond a modest size, switch to the cheap renderer: edges become thin
    // Rectangles (no curved QtQuick.Shapes, which are slow to build AND
    // re-tessellate on every drag) and weight/distance chips are dropped
    // (unreadable there, and hundreds of extra items). Kept low so moderate
    // graphs (e.g. 100 vertices / 200 edges) stay responsive to drag.
    readonly property bool dense: (ctl ? ctl.nodeCount : 0) > 60 || (ctl ? ctl.edgeCount : 0) > 100
    // Above this, drop per-node text too (names unreadable at that density) so the
    // delegates stay light enough to instantiate large graphs without a long freeze.
    readonly property bool superDense: (ctl ? ctl.nodeCount : 0) > 250 || (ctl ? ctl.edgeCount : 0) > 400
    // Non-repeating + re-armed so the event loop is guaranteed a gap between
    // batches (a tight repeating timer whose handler outruns its interval would
    // saturate the thread and still feel frozen).
    Timer {
        id: ramp
        interval: 16; repeat: false
        onTriggered: {
            // Bigger batches on very large graphs: fewer event-loop round-trips means
            // the whole ramp finishes sooner (each batch still yields before the next).
            gv.renderCount += (gv.superDense ? 120 : 40);
            if (gv.renderCount < gv.maxItems) restart();
            else gv.renderCount = gv.unlimited;
        }
    }
    // Call BEFORE applying a bulk load so the graphChanged that installs the new
    // data doesn't instantiate every delegate at once (renderCount gates them).
    function beginLoad() { ramp.stop(); gv.renderCount = 0; }
    // Call AFTER a bulk load/replace: ramp in when large, else show at once.
    function populate() {
        // Culling bounds how many delegates exist, so no progressive ramp is needed.
        // Start large graphs in the overview raster (no live delegates) — the caller
        // fits the view right after, and the zoom change reculls to the real state.
        // This avoids a transient live render of whatever happens to be in the
        // pre-fit viewport (the main load-time stall).
        if (gv.culling) {
            ramp.stop(); gv.renderCount = gv.unlimited;
            gv.overview = true; gv.visibleNodeIdx = []; gv.visibleEdgeIdx = [];
            gv.rebuildGrid();   // fitView() (called right after) reculls via its zoom change
        }
        else if (gv.maxItems > 150) { gv.renderCount = 0; ramp.restart(); }
        else { ramp.stop(); gv.renderCount = gv.unlimited; }
    }

    property real zoom: 1.0
    property real panX: 0
    property real panY: 0

    // --- interactive editing ---
    property bool edgeMode: false       // when on, tapping two nodes connects them
    property int pendingSrc: -1         // first node picked in edge mode
    property real newWeight: 1          // weight given to a freshly drawn edge

    // Click handling in edge mode: first tap picks the source, second draws the edge.
    function connectTap(vid) {
        if (pendingSrc < 0) { pendingSrc = vid; return; }
        if (vid !== pendingSrc && ctl) ctl.addEdge(pendingSrc, vid, newWeight);
        pendingSrc = -1;
    }
    onEdgeModeChanged: pendingSrc = -1

    function stateColor(s) {
        if (s === 1) return frontierEff;
        if (s === 2) return currentEff;
        if (s === 3) return settledEff;
        return nodeFillEff;
    }
    // Zoom by factor f, keeping the content point under (cx, cy) — in gv's own
    // coordinates — pinned to that spot. The Scale transform has its origin at
    // the view centre, so pan is adjusted to compensate.
    function zoomAt(f, cx, cy) {
        var z0 = zoom;
        var z1 = Math.max(0.05, Math.min(3.0, z0 * f));
        if (z1 === z0) return;
        var ox = width / 2, oy = height / 2, k = z1 / z0;
        panX = cx - ox - k * (cx - panX - ox);
        panY = cy - oy - k * (cy - panY - oy);
        zoom = z1;
    }
    // Buttons have no cursor — zoom around the view centre.
    function zoomBy(f) { zoomAt(f, width / 2, height / 2); }

    function nodeById(id) {
        var n = posMap[id];
        return n === undefined ? null : n;
    }

    // Perpendicular offset (px) for an edge's quadratic control point. Straight
    // (0) by default; bows reciprocal directed pairs apart, and bows an edge
    // aside when a non-endpoint vertex sits on its straight chord.
    function edgeBend(fromId, toId, idx) {
        if (!ctl) return 0;
        // A per-edge curve override (set from the Selection "Curve" slider) wins.
        if (idx !== undefined && edgeCurve[idx] !== undefined) return edgeCurve[idx];
        var a = nodeById(fromId), b = nodeById(toId);
        if (!a || !b) return 0;
        var dx = b.x - a.x, dy = b.y - a.y, len = Math.hypot(dx, dy);
        if (len < 1) return 0;
        // Reciprocal directed pair A->B and B->A: bow to opposite sides. This
        // separation is kept even in "straight" mode so the two don't coincide.
        if (ctl.directed) {
            var es = gv.edgeArr, E = es.length;
            for (var k = 0; k < E; k++)
                if (es[k].from === toId && es[k].to === fromId)
                    return (fromId < toId ? 1 : -1) * gv.nr * 1.4 * Math.max(0.5, gv.curvature);
        }
        // "Straight" mode skips the on-chord auto-bow below (only reciprocal pairs
        // above are separated).
        if (gv.edgeStyle === "straight") return 0;
        // A vertex sitting on/near the chord: bow away from it (scaled by curvature).
        var ux = dx / len, uy = dy / len, nx = -uy, ny = ux;   // unit chord + normal
        var ns = gv.nodeArr, N = ns.length;
        for (var i = 0; i < N; i++) {
            var p = ns[i];
            if (p.id === fromId || p.id === toId) continue;
            var t = ((p.x - a.x) * ux + (p.y - a.y) * uy);     // projection along chord
            if (t <= gv.nr || t >= len - gv.nr) continue;      // only between the endpoints
            var perp = (p.x - a.x) * nx + (p.y - a.y) * ny;    // signed distance from chord
            if (Math.abs(perp) < gv.nr)
                return (perp >= 0 ? -1 : 1) * (gv.nr + 18) * gv.curvature;  // push to the opposite side
        }
        return 0;
    }

    // Geometry shared by the edge Canvas and the weight chips: rim-trimmed
    // endpoints, the quadratic control point, and the on-curve midpoint.
    function edgeGeom(fromId, toId, idx) {
        var a = nodeById(fromId), b = nodeById(toId);
        if (!a || !b) return null;
        var dx = b.x - a.x, dy = b.y - a.y, len = Math.hypot(dx, dy);
        if (len < 1) len = 1;
        var ux = dx / len, uy = dy / len;
        var sx = a.x + ux * gv.nr, sy = a.y + uy * gv.nr;      // trimmed start
        var ex = b.x - ux * gv.nr, ey = b.y - uy * gv.nr;      // trimmed end
        var bend = edgeBend(fromId, toId, idx);
        var cx = (a.x + b.x) / 2 - uy * bend;                  // control point off the chord
        var cy = (a.y + b.y) / 2 + ux * bend;
        var mx = 0.25 * sx + 0.5 * cx + 0.25 * ex;             // bezier point at t=0.5
        var my = 0.25 * sy + 0.5 * cy + 0.25 * ey;
        return { sx: sx, sy: sy, ex: ex, ey: ey, cx: cx, cy: cy, mx: mx, my: my };
    }

    // Index of the active edge (animFrom <-> animTo) so edgeGeom picks up any
    // per-edge curve override; -1 falls back to the auto bend.
    function activeEdgeIdx() {
        var es = gv.edgeArr;
        for (var i = 0; i < es.length; i++)
            if ((es[i].from === animFrom && es[i].to === animTo)
                || (es[i].from === animTo && es[i].to === animFrom)) return i;
        return -1;
    }

    // Position + heading (deg) of the travelling token on the active edge at the
    // current tokenT — samples the SAME quadratic bezier the edge Shape renders.
    // The edge geometry is keyed to the STORED edge (ed.from -> ed.to); when the
    // traversal runs the other way (undirected edge discovered from the far end)
    // we sample the bezier in reverse so the token follows the drawn curve instead
    // of a mirror of it. The end is backed off so the arrowhead stops at the
    // destination's rim rather than overlapping the node. null when idle.
    function tokenPos() {
        if (animFrom < 0 || animTo < 0) return null;
        var idx = activeEdgeIdx();
        var ed = (idx >= 0) ? gv.edgeArr[idx] : null;
        var g, fwd;
        if (ed) { g = edgeGeom(ed.from, ed.to, idx); fwd = (ed.from === animFrom); }
        else    { g = edgeGeom(animFrom, animTo, -1); fwd = true; }   // fallback
        if (!g) return null;
        // Stop the token short of the destination node by ~the arrowhead length so
        // the tip lands on the rim, not inside the circle.
        var chord = Math.max(1, Math.hypot(g.ex - g.sx, g.ey - g.sy));
        var egap = Math.min(0.4, (10 * gv.tokenScale + 1) / chord);
        var tt = tokenT * (1 - egap);                 // 0 .. (1-egap)
        var t = fwd ? tt : (1 - tt);                  // reverse-sample for back edges
        var u = 1 - t;
        var x = u * u * g.sx + 2 * u * t * g.cx + t * t * g.ex;
        var y = u * u * g.sy + 2 * u * t * g.cy + t * t * g.ey;
        var dx = 2 * u * (g.cx - g.sx) + 2 * t * (g.ex - g.cx);
        var dy = 2 * u * (g.cy - g.sy) + 2 * t * (g.ey - g.cy);
        if (!fwd) { dx = -dx; dy = -dy; }             // heading along travel dir
        return { x: x, y: y, ang: Math.atan2(dy, dx) * 180 / Math.PI };
    }

    // Centre + scale the graph to fit the view.
    function fitView() {
        if (!ctl || nodeArr.length === 0 || width <= 0 || height <= 0) return;
        var ns = nodeArr, N = ns.length, minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9, m = nr + 40;
        for (var i = 0; i < N; i++) {
            minX = Math.min(minX, ns[i].x - m); maxX = Math.max(maxX, ns[i].x + m);
            minY = Math.min(minY, ns[i].y - m); maxY = Math.max(maxY, ns[i].y + m);
        }
        var bw = Math.max(1, maxX - minX), bh = Math.max(1, maxY - minY), pad = 20;
        var z = Math.max(0.05, Math.min(2.0, Math.min((width - 2 * pad) / bw, (height - 2 * pad) / bh)));
        zoom = z;
        panX = (width / 2 - (minX + maxX) / 2) * z;
        panY = (height / 2 - (minY + maxY) / 2) * z;
    }

    Rectangle { anchors.fill: parent; color: gv.canvasBg; z: -100 }

    // World-aligned background grid. Drawn in viewport space but offset/scaled
    // from pan+zoom so the lines track graph coordinates (and the origin gets a
    // stronger line). A single lightweight Canvas repainted on pan/zoom.
    Canvas {
        id: grid
        anchors.fill: parent
        z: -50
        visible: gv.showGrid
        renderStrategy: Canvas.Immediate
        renderTarget: Canvas.Image
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: gv
            function onPanXChanged() { grid.requestPaint(); }
            function onPanYChanged() { grid.requestPaint(); }
            function onZoomChanged() { grid.requestPaint(); }
            function onShowGridChanged() { grid.requestPaint(); }
        }
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (!gv.showGrid) return;
            var z = gv.zoom, cell = 40 * z;          // 40px world cells
            if (cell < 6) return;                     // too dense to help
            var cx = width / 2, cy = height / 2;
            var ox = gv.panX + cx * (1 - z);          // screen x of world x = 0
            var oy = gv.panY + cy * (1 - z);
            function first(o, s) { var f = o % s; return f > 0 ? f - s : f; }
            function lines(step, col) {
                ctx.beginPath(); ctx.lineWidth = 1; ctx.strokeStyle = col;
                for (var x = first(ox, step); x <= width; x += step) { var rx = Math.round(x) + 0.5; ctx.moveTo(rx, 0); ctx.lineTo(rx, height); }
                for (var y = first(oy, step); y <= height; y += step) { var ry = Math.round(y) + 0.5; ctx.moveTo(0, ry); ctx.lineTo(width, ry); }
                ctx.stroke();
            }
            lines(cell, gv.gridMinor);                // minor every cell
            lines(cell * 5, gv.gridMajor);            // major every 5 cells (origin included)
        }
    }

    Connections {
        target: gv.ctl
        enabled: gv.visible          // hidden view does no per-change work
        // Snapshot the per-edge state once per change (see edgeStateList). In
        // culling mode a structural change (add/remove/relayout) rebuilds the grid
        // and visible set — but not mid-drag, where moves fire graphChanged rapidly
        // and recomputing would churn the delegates (recull is a no-op while dragging).
        function onGraphChanged() {
            gv.refreshEdgeStates(); edges.requestPaint();
            if (gv.culling && !gv.dragging) cullTimer.restart();   // defer: run after the emit (clean cache)
        }
        function onCursorChanged() { gv.refreshEdgeStates(); edges.requestPaint(); }
        function onPathChanged() { gv.refreshEdgeStates(); edges.requestPaint(); }
    }
    // Catch up when this view is (re)shown after edits happened while hidden.
    onVisibleChanged: if (visible) { refreshEdgeStates(); populate(); Qt.callLater(fitView); }
    onWidthChanged: { if (gv.culling) cullTimer.restart(); Qt.callLater(fitView); }
    onHeightChanged: { if (gv.culling) cullTimer.restart(); Qt.callLater(fitView); }

    Item {
        id: content
        width: gv.width; height: gv.height
        x: gv.panX; y: gv.panY
        transform: Scale { origin.x: gv.width / 2; origin.y: gv.height / 2; xScale: gv.zoom; yScale: gv.zoom }

        // LOD overview raster (phase 2): a low-res image of the whole graph, drawn
        // once per change and scaled up over the world bbox. Shown only when zoomed
        // out far enough that live delegates would be too many (gv.overview). Sits
        // under everything; the live layers are empty while it's visible.
        Canvas {
            id: overviewCanvas
            visible: gv.overview
            z: -1
            // Paint on the GUI thread (like the grid canvas): a render-thread canvas
            // scheduling repaints trips "Updates can only be scheduled from GUI
            // thread" (flooding) on the threaded render loop during resize/2D↔3D.
            renderStrategy: Canvas.Immediate
            renderTarget: Canvas.Image
            x: gv.bbox.x; y: gv.bbox.y
            width: gv.ovW; height: gv.ovH
            transform: Scale { xScale: gv.bbox.w / Math.max(1, gv.ovW); yScale: gv.bbox.h / Math.max(1, gv.ovH) }
            onPaint: {
                var ctx = getContext("2d"); if (!ctx) return;
                ctx.reset();
                var ns = gv.nodeArr, es = gv.edgeArr, s = gv.ovScale, ox = gv.bbox.x, oy = gv.bbox.y;
                var E = es.length, Nn = ns.length;
                ctx.lineWidth = 1; ctx.strokeStyle = gv.edgeEff; ctx.globalAlpha = 0.7;
                ctx.beginPath();
                for (var j = 0; j < E; j++) {
                    var a = gv.nodeById(es[j].from), b = gv.nodeById(es[j].to);
                    if (!a || !b) continue;
                    ctx.moveTo((a.x - ox) * s, (a.y - oy) * s);
                    ctx.lineTo((b.x - ox) * s, (b.y - oy) * s);
                }
                ctx.stroke();
                ctx.globalAlpha = 1.0;
                var rad = Math.max(1.2, gv.nr * s);
                for (var i = 0; i < Nn; i++) {
                    var n = ns[i];
                    var st = gv.vstateAt(i);
                    ctx.fillStyle = (st === 0) ? (gv.nodeColors[i] !== undefined ? gv.nodeColors[i] : gv.nodeFillEff)
                                               : gv.stateColor(st);
                    ctx.beginPath();
                    ctx.arc((n.x - ox) * s, (n.y - oy) * s, rad, 0, 2 * Math.PI);
                    ctx.fill();
                }
            }
            Connections {
                target: gv.ctl; enabled: gv.visible
                function onGraphChanged() { overviewCanvas.requestPaint(); }
                function onCursorChanged() { overviewCanvas.requestPaint(); }
            }
            property int _sr: gv.styleRev
            on_SrChanged: requestPaint()
            onVisibleChanged: if (visible) requestPaint()
        }

        // Double-click empty canvas → add a node there (graph coordinates).
        TapHandler {
            acceptedButtons: Qt.LeftButton
            onDoubleTapped: function (ep) { if (gv.ctl && !gv.locked) gv.ctl.addVertex(ep.position.x, ep.position.y); }
            // A single tap on empty canvas clears the selection (node + edge).
            // Taps on nodes/edges are grabbed by their own MouseAreas, so this
            // only fires for empty space.
            onSingleTapped: function (ep, button) { gv.clearSel(); gv.clearEdgeSel(); }
        }
        DragHandler {
            target: null
            acceptedModifiers: Qt.NoModifier     // plain drag pans; Shift-drag box-selects (below)
            grabPermissions: PointerHandler.ApprovesTakeOverByHandlersOfSameType
                             | PointerHandler.ApprovesTakeOverByItems | PointerHandler.ApprovesCancellation
            property real sx: 0; property real sy: 0; property real p0x: 0; property real p0y: 0
            onActiveChanged: if (active) { sx = centroid.scenePosition.x; sy = centroid.scenePosition.y; p0x = gv.panX; p0y = gv.panY; }
            onCentroidChanged: if (active) { gv.panX = p0x + (centroid.scenePosition.x - sx); gv.panY = p0y + (centroid.scenePosition.y - sy); }
        }
        // Rubber-band box-select: Shift-drag empty canvas. centroid.position is in
        // `content` (graph) coords — the same space node x,y live in.
        DragHandler {
            id: band2d
            target: null
            acceptedModifiers: Qt.ShiftModifier
            grabPermissions: PointerHandler.ApprovesTakeOverByHandlersOfSameType
                             | PointerHandler.ApprovesTakeOverByItems | PointerHandler.ApprovesCancellation
            property real x0: 0; property real y0: 0; property real x1: 0; property real y1: 0
            onActiveChanged: {
                if (active) { x0 = x1 = centroid.position.x; y0 = y1 = centroid.position.y; return; }
                if (Math.abs(x1 - x0) < 3 && Math.abs(y1 - y0) < 3) return;   // just a shift-click on empty space
                var minx = Math.min(x0, x1), maxx = Math.max(x0, x1), miny = Math.min(y0, y1), maxy = Math.max(y0, y1);
                var m = {}; for (var k in gv.selectedSet) m[k] = true;        // additive (Shift)
                var ns = gv.nodeArr, N = ns.length, last = -1, inside = {};
                for (var i = 0; i < N; i++) {
                    var nd = ns[i];
                    if (nd.x >= minx && nd.x <= maxx && nd.y >= miny && nd.y <= maxy) { m[nd.id] = true; inside[nd.id] = true; last = nd.id; }
                }
                gv.selectedSet = m; if (last >= 0) gv.selected = last;
                // Edges whose BOTH endpoints are in the box join the selection too.
                var em = {}; for (var ke in gv.selectedEdgeSet) em[ke] = true;
                var es = gv.edgeArr, E = es.length;
                for (var j = 0; j < E; j++) if (inside[es[j].from] && inside[es[j].to]) em[j] = true;
                gv.selectedEdgeSet = em; gv.selRev++;
            }
            onCentroidChanged: if (active) { x1 = centroid.position.x; y1 = centroid.position.y; }
        }
        Rectangle {   // the selection box while dragging
            visible: band2d.active
            z: 20
            x: Math.min(band2d.x0, band2d.x1); y: Math.min(band2d.y0, band2d.y1)
            width: Math.abs(band2d.x1 - band2d.x0); height: Math.abs(band2d.y1 - band2d.y0)
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
            border.color: Theme.accent; border.width: 1
        }

        // Edge layer: retained QtQuick.Shapes geometry (GPU), not a repainted
        // Canvas image — keeps memory flat and avoids the large backing bitmap.
        // Each edge is a quadratic ShapePath (+ a filled arrowhead when directed),
        // bound to the cached geometry/run state so it updates reactively.
        // `requestPaint` is a kept no-op so existing callers stay valid.
        Item {
            id: edges
            anchors.fill: parent        // path coords are content coordinates
            function requestPaint() {}

            // Dense graphs draw each edge as a thin rotated Rectangle — the
            // lightest scene-graph item, far cheaper to instantiate than a Shape
            // (hundreds of Shapes freeze the load) and cheap to render/retain.
            // Straight lines only (curves are pointless at this density).
            // Ramp-capped so they populate progressively with the nodes.
            Repeater {
                model: gv.dense ? (gv.culling ? gv.visibleEdgeIdx : Math.min(gv.ctl ? gv.ctl.edgeCount : 0, gv.renderCount)) : 0
                delegate: Rectangle {
                    required property int modelData
                    readonly property int index: modelData
                    readonly property var ed: gv.edgeArr[index]
                    readonly property var na: ed ? gv.nodeById(ed.from) : null
                    readonly property var nb: ed ? gv.nodeById(ed.to) : null
                    // Single O(1) lookup into the precomputed state list.
                    readonly property int est: gv.edgeStateList.length > index ? gv.edgeStateList[index] : 0
                    readonly property bool active: est === 2
                    readonly property bool inTree: est === 1
                    readonly property bool onPath: est === 3
                    readonly property bool sel: (gv.selRev, gv.isEdgeSel(index))
                    visible: na !== null && nb !== null
                    antialiasing: true
                    transformOrigin: Item.TopLeft
                    readonly property real len: (na && nb) ? Math.hypot(nb.x - na.x, nb.y - na.y) : 0
                    x: na ? na.x : 0
                    y: (na ? na.y : 0) - height / 2
                    width: len
                    height: ((onPath ? 4 : ((active || inTree || sel) ? 3 : 1)) + (sel ? 1 : 0)) * gv.edgeWidthScale
                    rotation: (na && nb) ? Math.atan2(nb.y - na.y, nb.x - na.x) * 180 / Math.PI : 0
                    z: (onPath || sel) ? 1 : 0
                    color: onPath ? Theme.stPath
                                  : (active ? Theme.stActiveEdge
                                  : (inTree ? Theme.stTreeEdge
                                  : (sel ? Theme.accent : gv.edgeEff)))
                }
            }

            Repeater {
                // Stable integer model (read by index) so a graphChanged (e.g.
                // a drag) doesn't recreate every edge delegate; capped by
                // renderCount for progressive population. Disabled on dense
                // graphs (the Canvas above draws the edges instead).
                model: gv.dense ? 0 : Math.min(gv.ctl ? gv.ctl.edgeCount : 0, gv.renderCount)
                delegate: Shape {
                    id: es
                    required property int modelData
                    readonly property int index: modelData
                    readonly property var ed: gv.edgeArr[index]
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    z: (onPath || sel) ? 1 : 0         // draw highlighted/selected edges above others
                    readonly property var g: (gv.selRev, ed ? gv.edgeGeom(ed.from, ed.to, index) : null)
                    readonly property bool directed: gv.ctl ? gv.ctl.directed : false
                    // Precomputed per-edge state (see the dense layer above).
                    readonly property int est: gv.edgeStateList.length > index ? gv.edgeStateList[index] : 0
                    readonly property bool active: est === 2
                    readonly property bool inTree: est === 1
                    readonly property bool onPath: est === 3
                    readonly property bool sel: (gv.selRev, gv.isEdgeSel(index))
                    // Run highlights (path/active/tree) win over the selection accent.
                    readonly property color col: onPath ? Theme.stPath
                                                        : (active ? Theme.stActiveEdge
                                                        : (inTree ? Theme.stTreeEdge
                                                        : (sel ? Theme.accent : gv.edgeEff)))
                    readonly property var ah: {        // arrowhead triangle (directed only)
                        if (!g || !directed) return null;
                        var dx = g.ex - g.cx, dy = g.ey - g.cy, l = Math.hypot(dx, dy); if (l < 0.001) l = 1;
                        dx /= l; dy /= l;
                        var a = 11 * gv.arrowScale, w = 6 * gv.arrowScale, bx = g.ex - dx * a, by = g.ey - dy * a, nx = -dy, ny = dx;
                        return { tx: g.ex, ty: g.ey, lx: bx + nx * w, ly: by + ny * w, rx: bx - nx * w, ry: by - ny * w };
                    }
                    visible: g !== null

                    ShapePath {
                        strokeColor: es.col
                        strokeWidth: (es.onPath ? 4.5 : ((es.active || es.inTree) ? 3.5 : (es.sel ? 3.5 : 1.5))) * gv.edgeWidthScale
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        startX: es.g ? es.g.sx : 0
                        startY: es.g ? es.g.sy : 0
                        PathQuad {
                            x: es.g ? es.g.ex : 0; y: es.g ? es.g.ey : 0
                            controlX: es.g ? es.g.cx : 0; controlY: es.g ? es.g.cy : 0
                        }
                    }
                    ShapePath {                        // degenerate (invisible) when not directed
                        strokeWidth: 0
                        fillColor: es.col
                        startX: es.ah ? es.ah.tx : 0
                        startY: es.ah ? es.ah.ty : 0
                        PathLine { x: es.ah ? es.ah.lx : 0; y: es.ah ? es.ah.ly : 0 }
                        PathLine { x: es.ah ? es.ah.rx : 0; y: es.ah ? es.ah.ry : 0 }
                        PathLine { x: es.ah ? es.ah.tx : 0; y: es.ah ? es.ah.ty : 0 }
                    }
                }
            }
        }

        // Transparent click targets along each edge (non-dense only) so an edge can
        // be selected by clicking its line. A thin rotated band on the rim-to-rim
        // chord; z below the weight chips (so the chip still edits) and below nodes.
        Repeater {
            model: gv.dense ? 0 : Math.min(gv.ctl ? gv.ctl.edgeCount : 0, gv.renderCount)
            delegate: MouseArea {
                required property int modelData
                readonly property int index: modelData
                readonly property var ed: gv.edgeArr[index]
                readonly property var g: (gv.selRev, ed ? gv.edgeGeom(ed.from, ed.to, index) : null)
                visible: g !== null
                enabled: !gv.edgeMode              // don't hijack clicks while adding edges
                z: 4
                preventStealing: true              // grab the tap so empty-canvas taps stay distinct
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                transformOrigin: Item.TopLeft
                readonly property real len: g ? Math.hypot(g.ex - g.sx, g.ey - g.sy) : 0
                x: g ? g.sx : 0
                y: (g ? g.sy : 0) - height / 2
                width: len
                height: 12
                rotation: g ? Math.atan2(g.ey - g.sy, g.ex - g.sx) * 180 / Math.PI : 0
                onClicked: function (m) {
                    if (m.modifiers & Qt.ShiftModifier) gv.toggleEdgeSel(index);
                    else gv.selectEdgeOnly(index);
                }
            }
        }

        // Interactive edge-weight chips at the edge midpoints. Click to edit the
        // number in place; Enter or focus-out commits via ctl.setEdgeWeight.
        Repeater {
            // Stable int model, read by index; hidden entirely on dense graphs.
            model: gv.dense ? 0 : Math.min(gv.ctl ? gv.ctl.edgeCount : 0, gv.renderCount)
            delegate: Item {
                id: chip
                required property int modelData
                readonly property int index: modelData
                readonly property var ed: gv.edgeArr[index]
                readonly property var g: (gv.selRev, ed ? gv.edgeGeom(ed.from, ed.to, index) : null)   // follows the curve
                property bool editing: false
                visible: g !== null && gv.showLabels
                width: Math.max(26, wtext.implicitWidth + 12); height: 18; z: 5
                x: (g ? g.mx : 0) - width / 2
                y: (g ? g.my : 0) - height / 2

                function commit() {
                    var f = weditLoader.item;
                    var v = f ? parseFloat(f.text) : NaN;
                    if (!isNaN(v) && gv.ctl && ed) gv.ctl.setEdgeWeight(ed.from, ed.to, v);
                    editing = false;
                }

                Rectangle {
                    anchors.fill: parent; radius: 3
                    color: Theme.labelBg
                    border.color: chip.editing ? Theme.stActiveEdge : Theme.labelBorder
                    border.width: chip.editing ? 2 : 1
                    Text {
                        id: wtext
                        anchors.centerIn: parent; visible: !chip.editing
                        text: chip.ed ? ("" + chip.ed.weight) : ""
                        color: gv.labelEff; font.pixelSize: Math.round(11 * gv.labelScale); font.bold: true
                    }
                    // Editor created only while editing (see the node rename note).
                    Loader {
                        id: weditLoader
                        anchors.fill: parent
                        active: chip.editing
                        sourceComponent: TextField {
                            anchors.fill: parent
                            text: chip.ed ? ("" + chip.ed.weight) : ""
                            horizontalAlignment: TextInput.AlignHCenter
                            verticalAlignment: TextInput.AlignVCenter
                            font.pixelSize: 11; font.bold: true
                            padding: 0; background: null
                            color: Theme.labelText
                            selectByMouse: true
                            validator: DoubleValidator { bottom: 0 }
                            Component.onCompleted: { selectAll(); forceActiveFocus(); }
                            onAccepted: chip.commit()
                            onActiveFocusChanged: if (!activeFocus && chip.editing) chip.commit()
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent; visible: !chip.editing
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function (m) {
                        if (gv.locked) return;                    // scene locked → no weight edits
                        if (m.button === Qt.RightButton) {        // right-click a weight → delete that edge
                            if (gv.ctl && chip.ed) gv.ctl.removeEdge(chip.ed.from, chip.ed.to);
                            return;
                        }
                        chip.editing = true;                      // Loader focuses the field
                    }
                }
            }
        }

        // Travelling playback indicator: an arrow (or dot/comet) that rides the
        // active edge (animFrom -> animTo) as tokenT animates 0..1. Sits above the
        // edges, below the nodes. Only the small item moves — the arrow shape is
        // painted once (and on style/size change), not per frame.
        Item {
            id: tokenLayer
            z: 9
            readonly property var tp: (gv.tokenT, gv.animFrom, gv.animTo, gv.animEnabled,
                (gv.animEnabled && gv.tokenT < 1 && gv.animFrom >= 0 && gv.animTo >= 0)
                    ? gv.tokenPos() : null)
            visible: tp !== null
            x: tp ? tp.x : 0
            y: tp ? tp.y : 0
            rotation: tp ? tp.ang : 0
            Canvas {
                id: tokenCanvas
                width: 44; height: 44
                anchors.centerIn: parent
                renderStrategy: Canvas.Immediate   // GUI-thread paint (see overviewCanvas note)
                renderTarget: Canvas.Image
                // Repaint whenever the look (colour / style / size) changes or the
                // token is (re)shown — the shape is otherwise painted just once.
                property color _c: gv.tokenEff
                property string _s: gv.tokenStyle
                property real _sc: gv.tokenScale
                on_CChanged: requestPaint()
                on_SChanged: requestPaint()
                on_ScChanged: requestPaint()
                onVisibleChanged: if (visible) requestPaint()
                onPaint: {
                    var ctx = getContext("2d"); if (!ctx) return;
                    ctx.reset();
                    var cxp = width / 2, cyp = height / 2, s = gv.tokenScale, col = gv.tokenEff;
                    if (gv.tokenStyle === "dot") {
                        ctx.fillStyle = col; ctx.beginPath(); ctx.arc(cxp, cyp, 6 * s, 0, 2 * Math.PI); ctx.fill();
                        ctx.strokeStyle = "#ffffff"; ctx.lineWidth = 2 * s;
                        ctx.beginPath(); ctx.arc(cxp, cyp, 6 * s, 0, 2 * Math.PI); ctx.stroke();
                    } else if (gv.tokenStyle === "comet") {
                        for (var i = 3; i >= 1; i--) {
                            ctx.globalAlpha = 0.18 * i; ctx.fillStyle = col;
                            ctx.beginPath(); ctx.arc(cxp - 7 * s * i, cyp, (5 - i) * s, 0, 2 * Math.PI); ctx.fill();
                        }
                        ctx.globalAlpha = 1; ctx.fillStyle = col;
                        ctx.beginPath(); ctx.arc(cxp, cyp, 6 * s, 0, 2 * Math.PI); ctx.fill();
                    } else {   // chevron / arrow — points +x (local); item rotation gives heading
                        var a = 10 * s, w = 8 * s; ctx.fillStyle = col;
                        ctx.beginPath(); ctx.moveTo(cxp + a, cyp);
                        ctx.lineTo(cxp - a, cyp + w); ctx.lineTo(cxp - a, cyp - w);
                        ctx.closePath(); ctx.fill();
                    }
                }
            }
        }

        // Model is the vertex *count* (a stable int) rather than the nodes list,
        // so position/relax updates don't recreate delegates — otherwise a drag
        // would lose its grab mid-move. Per-vertex data is read by index and
        // re-evaluates via the notifying `nodes` property.
        Repeater {
            model: gv.culling ? gv.visibleNodeIdx : (gv.visible ? Math.min(gv.ctl ? gv.ctl.nodeCount : 0, gv.renderCount) : 0)
            delegate: Item {
                id: nodeItem
                required property int index
                readonly property int vid: index
                readonly property var nd: gv.nodeArr[index] !== undefined ? gv.nodeArr[index] : null
                readonly property string label: nd ? nd.label : ""
                // Painted state uses the lagged `visualStates` so a destination keeps
                // its prior colour until the travelling token arrives.
                readonly property int vstate: gv.visualStates.length > vid ? gv.visualStates[vid]
                                            : (gv.vstates.length > vid ? gv.vstates[vid] : 0)
                readonly property string vdist: gv.vdists.length > vid ? gv.vdists[vid] : ""
                // Idle fill: per-vertex override if painted, else the global fill.
                readonly property color idleColor: (gv.styleRev, gv.nodeColors[vid] !== undefined ? gv.nodeColors[vid] : gv.nodeFillEff)
                x: (nd ? nd.x : 0) - gv.nr; y: (nd ? nd.y : 0) - gv.nr
                width: gv.nr * 2; height: gv.nr * 2; z: 10
                visible: nd !== null
                transformOrigin: Item.Center

                // Arrival pulse — fires when the token reaches this vertex.
                SequentialAnimation {
                    id: arrivePulse
                    running: false
                    NumberAnimation { target: nodeItem; property: "scale"; from: 1.0; to: 1.45; duration: 150; easing.type: Easing.OutQuad }
                    NumberAnimation { target: nodeItem; property: "scale"; to: 1.0; duration: 220; easing.type: Easing.InQuad }
                }
                Connections {
                    target: gv
                    function onAnimArrived() { if (gv.animTo === nodeItem.vid) arrivePulse.restart(); }
                }

                property bool editing: false
                function commitRename() {
                    var f = nameEditLoader.item;
                    var t = f ? f.text.trim() : "";
                    if (t.length > 0 && gv.ctl) gv.ctl.renameVertex(vid, t);
                    editing = false;
                }
                function beginRename() { editing = true; }   // Loader focuses the field

                Rectangle {
                    anchors.fill: parent; radius: gv.nr
                    color: nodeItem.vstate === 0 ? nodeItem.idleColor : gv.stateColor(nodeItem.vstate)
                    border.color: nodeItem.editing ? Theme.stActiveEdge
                                                   : (nodeItem.vstate === 0 ? Theme.nodeBorder : Qt.darker(color, 1.3))
                    border.width: 2
                    Text {
                        anchors.centerIn: parent
                        visible: !nodeItem.editing && gv.showLabels && !gv.superDense
                        text: nodeItem.label
                        color: nodeItem.vstate === 0 ? Theme.nodeText : "#0b1220"
                        font.bold: true; font.pixelSize: gv.labelFont
                    }
                    // Rename editor is created only while editing — a full
                    // TextField per vertex would make large graphs slow to load.
                    Loader {
                        id: nameEditLoader
                        anchors.fill: parent
                        active: nodeItem.editing
                        sourceComponent: TextField {
                            anchors.centerIn: parent
                            width: nodeItem.width - 6
                            horizontalAlignment: TextInput.AlignHCenter
                            verticalAlignment: TextInput.AlignVCenter
                            font.bold: true; font.pixelSize: gv.labelFont
                            padding: 0; background: null
                            color: nodeItem.vstate === 0 ? Theme.nodeText : "#0b1220"
                            text: nodeItem.label
                            maximumLength: 12
                            selectByMouse: true
                            Component.onCompleted: { selectAll(); forceActiveFocus(); }
                            onAccepted: nodeItem.commitRename()
                            onActiveFocusChanged: if (!activeFocus && nodeItem.editing) nodeItem.commitRename()
                        }
                    }
                }
                Loader {   // distance chip under the node (Dijkstra) — created on demand
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom; anchors.topMargin: 2
                    active: gv.showLabels && !gv.dense && nodeItem.vdist.length > 0
                    sourceComponent: Rectangle {
                        width: dtxt.width + 8; height: dtxt.height + 2; radius: 3
                        color: Theme.labelBg; border.color: Theme.labelBorder; border.width: 1
                        Text { id: dtxt; anchors.centerIn: parent; text: "d=" + nodeItem.vdist
                               color: Theme.labelText; font.pixelSize: 11; font.bold: true }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    visible: !nodeItem.editing
                    preventStealing: true          // keep the grab on this node (canvas pan can't steal it)
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    // Dragging to re-layout is locked only while the animation
                    // is actively playing, so the diagram can't shift mid-play;
                    // paused / stopped / after a run, dragging is free again.
                    readonly property bool dragLocked: gv.edgeMode || gv.playing || gv.locked
                    cursorShape: dragLocked ? Qt.PointingHandCursor
                                            : (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                    property real px: 0; property real py: 0
                    property bool moved: false
                    property bool shiftPress: false
                    property real gsx: 0; property real gsy: 0   // drag start (content coords)
                    property var grpStart: ({})                  // id -> {x,y} at drag start
                    onPressed: function (m) {
                        moved = false; px = m.x; py = m.y;
                        shiftPress = (m.modifiers & Qt.ShiftModifier) !== 0;
                        if (m.button === Qt.LeftButton && !dragLocked && !shiftPress && nodeItem.nd) {
                            // Dragging an unselected node selects just it; a selected
                            // node keeps the set so the whole group drags together.
                            if (!gv.isSel(nodeItem.vid)) gv.selectOnly(nodeItem.vid);
                            var g = mapToItem(content, m.x, m.y);
                            gsx = g.x; gsy = g.y;
                            var snap = {}; var ns = gv.nodeArr, N = ns.length;
                            for (var i = 0; i < N; i++) if (gv.isSel(ns[i].id)) snap[ns[i].id] = { x: ns[i].x, y: ns[i].y };
                            grpStart = snap;
                        }
                    }
                    onPositionChanged: function (m) {
                        if (!(pressedButtons & Qt.LeftButton) || dragLocked || shiftPress) return;
                        // Ignore sub-threshold jitter so a plain click never starts a drag.
                        if (!moved && Math.hypot(m.x - px, m.y - py) < 4) return;
                        if (!moved && gv.ctl) gv.ctl.beginEdit();   // one undo step for the whole group drag
                        if (!moved) gv.dragging = true;             // freeze culling so this delegate isn't recreated
                        moved = true;
                        var g = mapToItem(content, m.x, m.y);
                        var dx = g.x - gsx, dy = g.y - gsy;
                        for (var id in grpStart) gv.ctl.moveVertex(+id, grpStart[id].x + dx, grpStart[id].y + dy);
                    }
                    onReleased: function (m) {
                        if (gv.dragging) { gv.dragging = false; if (gv.culling) { gv.rebuildGrid(); gv.recull(); } }
                    }
                    onClicked: function (m) {
                        if (m.button === Qt.RightButton) { if (!gv.locked) gv.ctl.removeVertex(nodeItem.vid); return; }
                        if (moved) return;                       // was a drag, not a tap
                        if (m.modifiers & Qt.ShiftModifier) { gv.toggleSel(nodeItem.vid); return; }   // add/remove
                        if (gv.edgeMode) { gv.selectOnly(nodeItem.vid); gv.connectTap(nodeItem.vid); return; }
                        gv.selectOnly(nodeItem.vid); gv.clearEdgeSel();   // plain click = single node
                        if (gv.ctl && gv.ctl.hasRun) {           // after a run: tap highlights the path here
                            if (gv.ctl.pathTarget === nodeItem.vid) gv.ctl.clearPath();
                            else gv.ctl.highlightPathTo(nodeItem.vid);
                        }
                        // (Rename is double-click only — see onDoubleClicked.)
                    }
                    onDoubleClicked: function (m) {              // double-click always renames
                        if (m.button !== Qt.LeftButton || gv.edgeMode || gv.locked) return;
                        nodeItem.beginRename();
                    }
                }
            }
        }

        // One ring each for the picked edge-source and the path target, placed
        // over the relevant vertex — cheaper than a ring (and animation) per node.
        Rectangle {
            property var n: (gv.pendingSrc >= 0) ? gv.nodeById(gv.pendingSrc) : null
            visible: n !== null; z: 11
            width: gv.nr * 2 + 12; height: width; radius: width / 2
            x: (n ? n.x : 0) - width / 2; y: (n ? n.y : 0) - height / 2
            color: "transparent"; border.color: Theme.stActiveEdge; border.width: 3
        }
        Rectangle {
            id: pathRing
            property var n: (gv.pathTarget >= 0) ? gv.nodeById(gv.pathTarget) : null
            visible: n !== null; z: 11
            width: gv.nr * 2 + 14; height: width; radius: width / 2
            x: (n ? n.x : 0) - width / 2; y: (n ? n.y : 0) - height / 2
            color: "transparent"; border.color: Theme.stPath; border.width: 3
            SequentialAnimation on scale {
                running: pathRing.visible
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 1.18; duration: 600; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 1.18; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
            }
        }
        // Static red ring marking the currently-selected start/source vertex.
        Rectangle {
            property var n: (gv.sourceVertex >= 0) ? gv.nodeById(gv.sourceVertex) : null
            visible: n !== null; z: 11
            width: gv.nr * 2 + 12; height: width; radius: width / 2
            x: (n ? n.x : 0) - width / 2; y: (n ? n.y : 0) - height / 2
            color: "transparent"; border.color: gv.srcEff; border.width: 3
        }
        // Accent ring around every selected node (multi-select; Style tab + group move).
        Repeater {
            model: (gv.selRev, Object.keys(gv.selectedSet))
            delegate: Rectangle {
                required property var modelData
                property var n: gv.nodeById(+modelData)
                visible: n !== null; z: 12
                width: gv.nr * 2 + 20; height: width; radius: width / 2
                x: (n ? n.x : 0) - width / 2; y: (n ? n.y : 0) - height / 2
                color: "transparent"; border.color: Theme.accent; border.width: 2
            }
        }
    }

    WheelHandler {
        acceptedModifiers: Qt.ControlModifier
        onWheel: function (e) { gv.zoomAt(e.angleDelta.y > 0 ? 1.1 : 1 / 1.1, e.x, e.y); }
    }

    // Draggable canvas panes (info / legend / edit / zoom) — Overlay2D.qml
    Overlay2D { view: gv }

    Component.onCompleted: { refreshEdgeStates(); Qt.callLater(fitView); }
}
