import QtQuick

// View-agnostic logic shared by the 2D and 3D graph canvases (GraphView2D and
// GraphView3D use this as their root type). Holds the node + edge selection
// model and the cached document snapshots; each subclass adds its own
// rendering, colours, layout, overlays and picking. Per-view bits that differ
// (edge-curve repaint, colours, selectionTip, node/label sizing) stay in the
// subclasses and simply call the inherited members here.
Item {
    id: base
    property var ctl

    // --- node selection: `selected` is the primary (last-touched) member the
    // Style sliders use; selectedSet drives the group drag + highlight. selRev
    // bumps dependent bindings. ---
    property int selected: -1
    property var selectedSet: ({})
    property int selRev: 0
    function isSel(id) { return selectedSet[id] === true; }
    function selCount() { var n = 0; for (var k in selectedSet) n++; return n; }
    function selectOnly(id) { var m = {}; if (id >= 0) m[id] = true; selectedSet = m; selected = id; selRev++; }
    function toggleSel(id) {
        var m = {}; for (var k in selectedSet) m[k] = selectedSet[k];
        if (m[id]) { delete m[id]; if (selected === id) selected = -1; }
        else { m[id] = true; selected = id; }
        selectedSet = m; selRev++;
    }
    function clearSel() { selectedSet = ({}); selected = -1; selRev++; }

    // --- edge selection (keyed by edge index); selectedEdge is the primary edge
    // the Curve slider uses. (The per-edge bend `edgeCurve` + its setters stay in
    // the subclass, which repaints via its own rev.) ---
    property var selectedEdgeSet: ({})
    property int selectedEdge: -1
    function isEdgeSel(i) { return selectedEdgeSet[i] === true; }
    function edgeSelCount() { var n = 0; for (var k in selectedEdgeSet) n++; return n; }
    function selectEdgeOnly(i) { var m = {}; if (i >= 0) m[i] = true; selectedEdgeSet = m; selectedEdge = i; clearSel(); selRev++; }  // clears nodes
    function toggleEdgeSel(i) {
        var m = {}; for (var k in selectedEdgeSet) m[k] = selectedEdgeSet[k];
        if (m[i]) { delete m[i]; if (selectedEdge === i) selectedEdge = -1; }
        else { m[i] = true; selectedEdge = i; }
        selectedEdgeSet = m; selRev++;
    }
    function clearEdgeSel() { selectedEdgeSet = ({}); selectedEdge = -1; selRev++; }
    // Ids the style/colour helpers act on: the whole set, or the primary if empty.
    function _selIds() {
        var ids = []; for (var k in selectedSet) ids.push(+k);
        if (ids.length === 0 && selected >= 0) ids.push(selected);
        return ids;
    }
    function _edgeSelIds() {
        var ids = []; for (var k in selectedEdgeSet) ids.push(+k);
        if (ids.length === 0 && selectedEdge >= 0) ids.push(selectedEdge);
        return ids;
    }

    // --- cached document snapshots. Iterating the QVariantList (ctl.nodes) per
    // element in JS is O(n^2) (the sequence wrapper reconverts per access), so
    // parse the JSON once; gated on `visible` so a hidden view does no per-change
    // work. ---
    readonly property var nodeList: (ctl && visible) ? ctl.nodes : []
    readonly property var edgeList: (ctl && visible) ? ctl.edges : []
    readonly property var nodeArr: (ctl && visible) ? JSON.parse(ctl.nodesJson) : []
    readonly property var edgeArr: (ctl && visible) ? JSON.parse(ctl.edgesJson) : []
    readonly property int nodeCount: (ctl && visible) ? ctl.nodeCount : 0
    readonly property int edgeCount: (ctl && visible) ? ctl.edgeCount : 0
    readonly property bool directed: ctl ? ctl.directed : false
    readonly property var vstates: (ctl && visible) ? ctl.vertexStates : []
    readonly property var vdists: (ctl && visible) ? ctl.vertexDists : []
    property var edgeStateList: []
    function refreshEdgeStates() { edgeStateList = ctl ? ctl.edgeStates() : []; }

    // --- playback animation (FSM-style travelling indicator) -------------------
    // On a forward step the active edge (ctl.activeFrom -> ctl.activeTo) drives a
    // token that travels along it; the DESTINATION vertex keeps its prior colour
    // until the token arrives (tokenAnim.onFinished), then flips + pulses. All
    // other vertices update immediately, so the source lights up at step start.
    // Subclasses render the token (2D overlay / 3D Node) and pulse `animTo` on
    // `animArrived()`. `visualStates` is what the view paints (lagged dest).
    property bool animEnabled: true
    property string tokenStyle: "chevron"   // "chevron" | "dot" | "comet"
    property real tokenScale: 1.0            // 0.5..2 size multiplier
    property real tokenT: 1                  // 0..1 progress along the active edge
    property int animFrom: -1                // active edge endpoints while travelling
    property int animTo: -1
    property int stepMs: 450                 // play interval (set by the view from playSpeed)
    property var visualStates: []            // vertex states actually painted (dest lags)
    property int _lastCursor: -1
    signal animArrived()                     // token reached animTo — pulse it

    // Preferred (lagged) state for vertex i: visualStates when present, else live.
    function vstateAt(i) {
        return (visualStates.length > i) ? visualStates[i]
             : (vstates.length > i ? vstates[i] : 0);
    }

    NumberAnimation {
        id: tokenAnim
        target: base; property: "tokenT"; from: 0; to: 1
        duration: Math.max(120, Math.round(base.stepMs * 0.75))
        easing.type: Easing.InOutQuad
        onFinished: {                         // hand off: destination updates + pulses
            base.visualStates = base.ctl ? base.ctl.vertexStates : [];
            base.animArrived();
        }
    }

    Connections {
        target: base.ctl
        enabled: base.ctl !== null
        function onCursorChanged() { base._onCursor(); }
    }

    // Snap the painted state to the controller (no travel). Used on seek / step-back
    // / build / disable / view-switch.
    function _snapStates() {
        tokenAnim.stop(); tokenT = 1; animFrom = -1; animTo = -1;
        visualStates = ctl ? ctl.vertexStates : [];
    }

    function _onCursor() {
        if (!ctl) return;
        var cur = ctl.cursor;
        var fwd = (cur === _lastCursor + 1);   // single forward step (play / Step ▶▶)
        _lastCursor = cur;
        var af = ctl.activeFrom, at = ctl.activeTo;
        var ns = ctl.vertexStates;
        if (animEnabled && visible && fwd && af >= 0 && at >= 0 && af !== at && at < ns.length) {
            // Apply the new states to everything except the destination, which keeps
            // its prior colour until the token arrives.
            var prior = (visualStates.length > at) ? visualStates[at] : 0;
            var copy = [];
            for (var i = 0; i < ns.length; i++) copy[i] = ns[i];
            copy[at] = prior;
            visualStates = copy;
            animFrom = af; animTo = at;
            tokenT = 0; tokenAnim.restart();
        } else {
            _snapStates();
        }
    }
    // NOTE: no root onVisibleChanged / Component.onCompleted here — a subclass's
    // own handlers would override them. Init is implicit: vstateAt() falls back to
    // the live states until visualStates is first set, and a hidden view still
    // snaps on every cursorChanged (visible === false path above).

    // --- colour roles (paint-bucket + per-role overrides) ----------------------
    // Each subclass supplies the default (theme) colour for every role via the
    // def* inputs; an override with alpha > 0 wins. Swatches bind the *Eff props;
    // applyColor / paintRole set them. styleRev bumps colour-dependent bindings.
    property color defNodeFill: "#1e293b"
    property color defEdge: "#64748b"
    property color defLabel: "#e2e8f0"
    property color defSource: "#ef4444"
    property color defFrontier: "#3b82f6"
    property color defCurrent: "#f59e0b"
    property color defSettled: "#22c55e"
    // Edge-state colours (shown after a run): traversed/tree, active, and the
    // selected shortest path. Overridable like the node-state roles above.
    property color defTreeEdge: "#22c55e"
    property color defActiveEdge: "#f59e0b"
    property color defPathEdge: "#ec4899"
    property color defToken: "#ffffff"        // travelling-indicator colour (subclass: Theme.textPrimary)

    property color nodeFillOverride: "transparent"
    property color edgeOverride: "transparent"
    property color labelOverride: "transparent"
    property color srcOverride: "transparent"
    property color frontierOverride: "transparent"
    property color currentOverride: "transparent"
    property color settledOverride: "transparent"
    property color treeEdgeOverride: "transparent"
    property color activeEdgeOverride: "transparent"
    property color pathEdgeOverride: "transparent"
    property color tokenOverride: "transparent"
    readonly property color nodeFillEff: nodeFillOverride.a > 0 ? nodeFillOverride : defNodeFill
    readonly property color edgeEff:     edgeOverride.a     > 0 ? edgeOverride     : defEdge
    readonly property color labelEff:    labelOverride.a    > 0 ? labelOverride    : defLabel
    readonly property color srcEff:      srcOverride.a      > 0 ? srcOverride      : defSource
    readonly property color frontierEff: frontierOverride.a > 0 ? frontierOverride : defFrontier
    readonly property color currentEff:  currentOverride.a  > 0 ? currentOverride  : defCurrent
    readonly property color settledEff:  settledOverride.a  > 0 ? settledOverride  : defSettled
    readonly property color treeEdgeEff:   treeEdgeOverride.a   > 0 ? treeEdgeOverride   : defTreeEdge
    readonly property color activeEdgeEff: activeEdgeOverride.a > 0 ? activeEdgeOverride : defActiveEdge
    readonly property color pathEdgeEff:   pathEdgeOverride.a   > 0 ? pathEdgeOverride   : defPathEdge
    readonly property color tokenEff:      tokenOverride.a      > 0 ? tokenOverride      : defToken

    property color workingColor: "#f59e0b"   // paint-bucket colour
    property int styleRev: 0                  // bump to re-evaluate colour bindings
    property var nodeColors: ({})             // per-vertex idle fill override (id -> colour string)

    function colorForRole(role) {
        return role === "node"     ? nodeFillEff
             : role === "edge"     ? edgeEff
             : role === "label"    ? labelEff
             : role === "source"   ? srcEff
             : role === "frontier" ? frontierEff
             : role === "current"  ? currentEff
             : role === "settled"  ? settledEff
             : role === "treeedge"   ? treeEdgeEff
             : role === "activeedge" ? activeEdgeEff
             : role === "path"       ? pathEdgeEff
             : role === "token"      ? tokenEff
             : role === "nodesel"  ? selectedNodeColor()
             :                        nodeFillEff;
    }
    function applyColor(role, c) {
        if (role === "node")          nodeFillOverride = c;
        else if (role === "edge")     edgeOverride = c;
        else if (role === "label")    labelOverride = c;
        else if (role === "source")   srcOverride = c;
        else if (role === "frontier") frontierOverride = c;
        else if (role === "current")  currentOverride = c;
        else if (role === "settled")  settledOverride = c;
        else if (role === "treeedge")   treeEdgeOverride = c;
        else if (role === "activeedge") activeEdgeOverride = c;
        else if (role === "path")       pathEdgeOverride = c;
        else if (role === "token")      tokenOverride = c;
        else if (role === "nodesel")  applySelectedColor(c);
        workingColor = c;
        styleRev++;   // repaint now so the scene recolours immediately
    }
    function paintRole(role) { applyColor(role, workingColor); }
    function resetColors() {
        nodeFillOverride = "transparent"; edgeOverride = "transparent"; labelOverride = "transparent";
        srcOverride = "transparent"; frontierOverride = "transparent";
        currentOverride = "transparent"; settledOverride = "transparent";
        treeEdgeOverride = "transparent"; activeEdgeOverride = "transparent";
        pathEdgeOverride = "transparent"; tokenOverride = "transparent";
        nodeColors = ({}); styleRev++;
    }
    function selectedNodeColor() {
        if (selected < 0) return nodeFillEff;
        return (nodeColors[selected] !== undefined) ? nodeColors[selected] : nodeFillEff;
    }
    function applySelectedColor(c) {
        var ids = _selIds(); if (ids.length === 0) return;
        var m = {}; for (var k in nodeColors) m[k] = nodeColors[k];
        for (var i = 0; i < ids.length; i++) m[ids[i]] = "" + c;
        nodeColors = m; styleRev++;
    }
    function clearSelectedColor() {
        var ids = _selIds(); if (ids.length === 0) return;
        var drop = {}; for (var i = 0; i < ids.length; i++) drop[ids[i]] = true;
        var m = {}; for (var k in nodeColors) if (!drop[+k]) m[k] = nodeColors[k];
        nodeColors = m; styleRev++;
    }
}
