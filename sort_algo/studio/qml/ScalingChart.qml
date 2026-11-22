pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SortStudio
import UiKit

// Metric-vs-N scaling chart: one poly-line per algorithm. A metric selector switches
// the y-axis between median time, comparisons, swaps and writes; an optional Big-O
// overlay draws dashed O(n log n) and O(n²) reference shapes (anchored at the top-
// right) so you can eyeball which family a curve follows. Legend is a vertical strip
// on the right; Canvas-drawn (anchored, not in a Layout, so it repaints on resize).
Rectangle {
    id: chart
    property var results: []
    property var algoOrder: []
    property string metric: "time"          // time | comparisons | swaps | writes
    property bool showReference: false

    color: Theme.panelBg
    border.color: Theme.panelBorder
    radius: 8

    readonly property var palLight: ["#2a78d6","#eb6834","#1baf7a","#eda100","#e87ba4","#6250d6","#008300","#e34948"]
    readonly property var palDark:  ["#3987e5","#d95926","#199e70","#c98500","#d55181","#9085e9","#0ca30c","#e66767"]
    function seriesColor(algo) {
        var i = chart.algoOrder.indexOf(algo);
        if (i < 0) i = 0;
        var p = Theme.dark ? chart.palDark : chart.palLight;
        return p[i % p.length];
    }

    readonly property int legendWidth: 108
    readonly property int topBar: 36
    readonly property var metrics: [
        { key: "time",        label: "Time (ms)" },
        { key: "cpu",         label: "CPU (ms)" },
        { key: "memory",      label: "Peak memory" },
        { key: "comparisons", label: "Comparisons" },
        { key: "swaps",       label: "Swaps" },
        { key: "writes",      label: "Writes" }
    ]
    function metricValue(r) {
        if (chart.metric === "comparisons") return r.compares;
        if (chart.metric === "swaps") return r.swaps;
        if (chart.metric === "writes") return r.writes;
        if (chart.metric === "cpu") return Math.max(0, r.cpuMs);      // -1 (N/A) -> 0
        if (chart.metric === "memory") return r.memBytes;
        return r.medianMs;
    }
    function fmtVal(v) {
        if (chart.metric === "time" || chart.metric === "cpu") return v >= 10 ? v.toFixed(0) : v.toFixed(2);
        if (chart.metric === "memory") {
            if (v >= 1024 * 1024) return (v / (1024 * 1024)).toFixed(1) + "M";
            if (v >= 1024) return (v / 1024).toFixed(1) + "K";
            return Math.round(v) + "B";
        }
        if (v >= 1e6) return (v / 1e6).toFixed(1) + "M";
        if (v >= 1e3) return (v / 1e3).toFixed(1) + "K";
        return Math.round(v).toString();
    }

    // Group rows into [{ name, pts:[{n, v}] }] by first-seen algorithm, sorted by N.
    function series() {
        var map = ({}), order = [];
        for (var i = 0; i < results.length; i++) {
            var r = results[i];
            if (!map[r.algorithm]) { map[r.algorithm] = []; order.push(r.algorithm); }
            map[r.algorithm].push({ n: r.n, v: chart.metricValue(r) });
        }
        var out = [];
        for (var k = 0; k < order.length; k++) {
            var pts = map[order[k]];
            pts.sort(function (p, q) { return p.n - q.n; });
            out.push({ name: order[k], pts: pts });
        }
        return out;
    }

    onResultsChanged: canvas.requestPaint()
    onMetricChanged: canvas.requestPaint()
    onShowReferenceChanged: canvas.requestPaint()
    property bool _dark: Theme.dark
    on_DarkChanged: canvas.requestPaint()

    // ---- top toolbar: metric selector + Big-O overlay toggle ----
    RowLayout {
        id: toolbar
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 10 }
        height: 26
        spacing: 8
        Label { text: "Metric"; color: Theme.textMuted; font.pixelSize: 12 }
        UiComboBox {
            Layout.preferredWidth: 150
            model: chart.metrics.map(function (m) { return m.label; })
            currentIndex: {
                for (var i = 0; i < chart.metrics.length; i++)
                    if (chart.metrics[i].key === chart.metric) return i;
                return 0;
            }
            onActivated: chart.metric = chart.metrics[currentIndex].key
        }
        Item { Layout.fillWidth: true }
        CheckBox {
            text: "Big-O overlay"
            checked: chart.showReference
            onToggled: chart.showReference = checked
            contentItem: Label { text: parent.text; color: Theme.textPrimary; font.pixelSize: 12
                                 leftPadding: parent.indicator.width + 6; verticalAlignment: Text.AlignVCenter }
        }
    }

    Label {
        anchors.centerIn: parent
        visible: chart.results.length === 0
        text: "Run a sweep to see the scaling curves."
        color: Theme.textMuted
        font.pixelSize: 13
    }

    // ---- vertical legend, pinned right (below the toolbar) ----
    Column {
        id: legend
        visible: chart.results.length > 0
        width: chart.legendWidth
        anchors { right: parent.right; top: parent.top; topMargin: chart.topBar + 8; rightMargin: 14 }
        spacing: 6
        Repeater {
            model: chart.series()
            delegate: Row {
                required property var modelData
                spacing: 6
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16; height: 3; radius: 1
                    color: chart.seriesColor(modelData.name)
                }
                Label {
                    width: chart.legendWidth - 22
                    text: modelData.name
                    color: Theme.textPrimary
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
        }
    }

    // ---- plot (right of the legend, below the toolbar) ----
    Canvas {
        id: canvas
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.topMargin: chart.topBar + 8
        anchors.rightMargin: chart.legendWidth + 48
        anchors.bottomMargin: 12
        visible: chart.results.length > 0
        renderStrategy: Canvas.Immediate
        renderTarget: Canvas.Image

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var S = chart.series();
            if (S.length === 0) return;

            var padL = 72, padB = 28, padT = 10, padR = 6;
            var w = width - padL - padR, h = height - padT - padB;
            if (w <= 0 || h <= 0) return;

            var maxN = 0, maxV = 0;
            for (var i = 0; i < S.length; i++)
                for (var j = 0; j < S[i].pts.length; j++) {
                    maxN = Math.max(maxN, S[i].pts[j].n);
                    maxV = Math.max(maxV, S[i].pts[j].v);
                }
            if (maxN <= 0) maxN = 1;
            if (maxV <= 0) maxV = 1;

            function X(n) { return padL + (n / maxN) * w; }
            function Y(v) { return padT + h - (v / maxV) * h; }

            // axes
            ctx.strokeStyle = Qt.rgba(0.5, 0.56, 0.64, 0.6);
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(padL, padT); ctx.lineTo(padL, padT + h); ctx.lineTo(padL + w, padT + h);
            ctx.stroke();

            // axis labels
            ctx.fillStyle = Qt.rgba(0.6, 0.66, 0.73, 1);
            ctx.font = "10px sans-serif";
            ctx.textAlign = "right"; ctx.textBaseline = "middle";
            ctx.fillText(chart.fmtVal(maxV), padL - 8, padT + 6);
            ctx.fillText("0", padL - 8, padT + h);
            ctx.textBaseline = "alphabetic";
            ctx.textAlign = "center";
            ctx.fillText("0", padL, padT + h + 18);
            ctx.textAlign = "right";
            ctx.fillText("N = " + maxN, padL + w, padT + h + 18);

            // ---- Big-O reference shapes (dashed, anchored at maxN -> maxV) ----
            if (chart.showReference && maxN > 1) {
                var refs = [
                    { label: "O(n log n)", f: function (n) { return n * Math.log(n) / Math.LN2; } },
                    { label: "O(n²)",       f: function (n) { return n * n; } }
                ];
                ctx.setLineDash([5, 4]);
                ctx.lineWidth = 1.3;
                for (var ri = 0; ri < refs.length; ri++) {
                    var fmax = refs[ri].f(maxN);
                    if (fmax <= 0) continue;
                    ctx.strokeStyle = Qt.rgba(0.62, 0.68, 0.75, 0.8);
                    ctx.beginPath();
                    var first = true;
                    for (var n = 1; n <= maxN; n += Math.max(1, Math.floor(maxN / 60))) {
                        var yy = refs[ri].f(n) / fmax * maxV;
                        var sx = X(n), sy = Y(yy);
                        if (first) { ctx.moveTo(sx, sy); first = false; } else ctx.lineTo(sx, sy);
                    }
                    ctx.stroke();
                    ctx.setLineDash([]);
                    ctx.fillStyle = Qt.rgba(0.62, 0.68, 0.75, 0.9);
                    ctx.font = "9px sans-serif";
                    ctx.textAlign = "right"; ctx.textBaseline = "bottom";
                    ctx.fillText(refs[ri].label, padL + w, Y(maxV) + (ri * 11) + 10);
                    ctx.setLineDash([5, 4]);
                }
                ctx.setLineDash([]);
            }

            // series lines + point markers
            for (var s = 0; s < S.length; s++) {
                var col = chart.seriesColor(S[s].name);
                ctx.strokeStyle = col; ctx.fillStyle = col; ctx.lineWidth = 2;
                ctx.beginPath();
                var pts = S[s].pts;
                for (var p = 0; p < pts.length; p++) {
                    var x = X(pts[p].n), y = Y(pts[p].v);
                    if (p === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                }
                ctx.stroke();
                for (var q = 0; q < pts.length; q++) {
                    ctx.beginPath();
                    ctx.arc(X(pts[q].n), Y(pts[q].v), 2.5, 0, 2 * Math.PI);
                    ctx.fill();
                }
            }
        }
    }
}
