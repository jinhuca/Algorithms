pragma ComponentBehavior: Bound
import QtQuick
import GraphVis

// A small line chart of a benchmark metric vs graph size N, one line per
// algorithm. Single y-axis (the metric toggle in AnalyzerPage switches between
// time and peak memory — never a dual axis). Colours are the dataviz categorical
// palette, assigned by the algorithm's fixed index so an algorithm keeps its hue
// regardless of which others are shown; a legend names every series.
Item {
    id: chart

    property var results: []       // AnalyzerController.results rows
    property var algoOrder: []     // fixed algorithm order → stable colour per algorithm
    property string metric: "time" // "time" (mean ms) | "mem" (peak KB/MB)

    // dataviz categorical slots (light / dark), assigned by the algorithm's fixed
    // index. Violet is placed at slot 6 (ahead of green at slot 7) so the six
    // algorithms land on blue / orange / aqua / yellow / magenta / violet — i.e.
    // Dijkstra=aqua and Prim=violet, well separated. (The previous order gave Prim
    // the green slot, which read almost identically to Dijkstra's aqua.)
    readonly property var palLight: ["#2a78d6","#eb6834","#1baf7a","#eda100","#e87ba4","#6250d6","#008300","#e34948"]
    readonly property var palDark:  ["#3987e5","#d95926","#199e70","#c98500","#d55181","#9085e9","#0ca30c","#e66767"]
    function seriesColor(algo) {
        var i = chart.algoOrder.indexOf(algo);
        if (i < 0) i = 0;
        var p = Theme.dark ? chart.palDark : chart.palLight;
        return p[i % p.length];
    }

    // Repaint on any input or theme change (and drop any stale hover on new data).
    onResultsChanged: { chart.hoverIndex = -1; canvas.requestPaint(); }
    onMetricChanged: { chart.hoverIndex = -1; canvas.requestPaint(); }
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()
    property bool _dark: Theme.dark
    on_DarkChanged: canvas.requestPaint()

    function niceCeil(v) {
        if (v <= 0) return 1;
        var e = Math.floor(Math.log(v) / Math.LN10);
        var base = Math.pow(10, e);
        var f = v / base;
        var nf = f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10;
        return nf * base;
    }
    function fmtY(v) {
        if (chart.metric === "time") return v >= 10 ? v.toFixed(0) : v.toFixed(1);
        return v >= 1024 ? (v / 1024).toFixed(1) + "M" : v.toFixed(0) + "K";   // KB → M(B)
    }

    // ---- hover tooltip -------------------------------------------------------
    // onPaint records each drawn marker's screen position + its data here, so the
    // MouseArea can hit-test the cursor against the dots without re-deriving the
    // plot geometry. `val` is the plotted metric value (ms for time, KB for mem).
    property var points: []          // [{px, py, algo, n, val}]
    property int hoverIndex: -1

    // Exact value of the hovered point, formatted for its metric.
    function fmtHoverVal(val) {
        if (chart.metric === "time")
            return (val < 1 ? val.toFixed(3) : val.toFixed(2)) + " ms";
        // val is in KB
        if (val < 1) return (val * 1024).toFixed(0) + " B";
        if (val < 1024) return val.toFixed(1) + " KB";
        return (val / 1024).toFixed(2) + " MB";
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        // Paint on the GUI thread (like the canvases in GraphView2D): a render-thread
        // canvas scheduling repaints trips "Updates can only be scheduled from GUI
        // thread" when the chart is resized rapidly — e.g. dragging the results/chart
        // splitter floods onWidthChanged/onHeightChanged → requestPaint().
        renderStrategy: Canvas.Immediate
        renderTarget: Canvas.Image
        onPaint: {
            var ctx = getContext("2d");
            var W = width, H = height;
            ctx.reset();
            ctx.clearRect(0, 0, W, H);

            var textP = Theme.textPrimary, textM = Theme.textMuted, grid = Theme.panelBorder;
            var rows = chart.results || [];
            var hitPoints = [];         // rebuilt every paint; drives the hover tooltip

            // group rows into series by algorithm; find domains
            var series = {}, order = [];
            var maxY = 0, minX = Infinity, maxX = -Infinity;
            for (var i = 0; i < rows.length; i++) {
                var r = rows[i];
                var y = chart.metric === "time" ? r.meanMs : (r.memBytes / 1024);  // KB
                var x = r.n;
                if (!series[r.algorithm]) { series[r.algorithm] = []; order.push(r.algorithm); }
                series[r.algorithm].push({ x: x, y: y });
                if (y > maxY) maxY = y;
                if (x < minX) minX = x;
                if (x > maxX) maxX = x;
            }

            ctx.font = "13px sans-serif";
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";
            if (order.length === 0 || maxY <= 0) {
                ctx.fillStyle = textM;
                ctx.fillText("Run a benchmark to see time / memory scaling.", W / 2, H / 2);
                chart.points = hitPoints;
                return;
            }

            maxY = chart.niceCeil(maxY);
            // mL leaves room for: the rotated axis title (~x=14) + a gap + the
            // right-aligned tick labels (right edge at x0-8). Widened so the widest
            // tick (e.g. "11.7M") no longer crowds the title.
            // mB is the gap between the plot baseline and the legend below. No x-axis
            // labels now, but keep enough room so baseline points don't touch the legend.
            var mL = 72, mR = 14, mT = 14, mB = 24, legendH = 26;
            var plotW = W - mL - mR, plotH = H - mT - mB - legendH;
            if (plotW < 30 || plotH < 30) { chart.points = hitPoints; return; }
            var x0 = mL, yBase = mT + plotH;
            var lo = (minX === maxX) ? 0 : minX;   // single size → range from 0 so the point isn't on the axis
            function sx(x) { return x0 + (maxX > lo ? (x - lo) / (maxX - lo) : 0.5) * plotW; }
            function sy(y) { return yBase - (y / maxY) * plotH; }

            // y gridlines + labels
            ctx.strokeStyle = grid;
            ctx.lineWidth = 1;
            ctx.font = "11px sans-serif";
            ctx.fillStyle = textM;
            ctx.textAlign = "right";
            for (var t = 0; t <= 5; t++) {
                var yv = maxY * t / 5, py = sy(yv);
                ctx.globalAlpha = 0.45;
                ctx.beginPath(); ctx.moveTo(x0, py); ctx.lineTo(x0 + plotW, py); ctx.stroke();
                ctx.globalAlpha = 1;
                ctx.fillText(chart.fmtY(yv), x0 - 8, py);
            }
            // axis title (y)
            ctx.save();
            ctx.translate(14, mT + plotH / 2);
            ctx.rotate(-Math.PI / 2);
            ctx.textAlign = "center";
            ctx.fillStyle = textM;
            ctx.fillText(chart.metric === "time" ? "mean (ms)" : "peak memory", 0, 0);
            ctx.restore();

            // (No x-axis tick labels: with many sizes they overlap into an unreadable
            // smear. The exact N for any point is available by hovering it.)

            // series polylines + markers — clipped to the plot rectangle so nothing
            // (marker edges, a steep segment) spills below the 0.0 baseline or above the
            // top gridline.
            ctx.save();
            ctx.beginPath();
            ctx.rect(x0, mT, plotW, plotH);
            ctx.clip();
            for (var s = 0; s < order.length; s++) {
                var algo = order[s];
                var pts = series[algo].slice().sort(function (a, b) { return a.x - b.x; });
                var col = chart.seriesColor(algo);
                ctx.strokeStyle = col;
                ctx.fillStyle = col;
                ctx.lineWidth = 2;
                ctx.beginPath();
                for (var j = 0; j < pts.length; j++) {
                    var px = sx(pts[j].x), pyv = sy(pts[j].y);
                    if (j === 0) ctx.moveTo(px, pyv); else ctx.lineTo(px, pyv);
                }
                ctx.stroke();
                for (var j2 = 0; j2 < pts.length; j2++) {
                    var mx = sx(pts[j2].x), myv = sy(pts[j2].y);
                    ctx.beginPath();
                    ctx.arc(mx, myv, 3.5, 0, 2 * Math.PI);
                    ctx.fill();
                    hitPoints.push({ px: mx, py: myv, algo: algo, n: pts[j2].x, val: pts[j2].y });
                }
            }
            ctx.restore();
            chart.points = hitPoints;

            // legend (bottom), swatch + algorithm name in text ink
            var lx = x0, ly = H - legendH / 2;
            ctx.textAlign = "left";
            ctx.textBaseline = "middle";
            ctx.font = "12px sans-serif";
            for (var m = 0; m < order.length; m++) {
                var name = order[m];
                ctx.fillStyle = chart.seriesColor(name);
                ctx.fillRect(lx, ly - 5, 12, 10);
                ctx.fillStyle = textP;
                ctx.fillText(name, lx + 17, ly);
                lx += 17 + ctx.measureText(name).width + 22;
            }
        }
    }

    // Convenience handle on the hovered point (null when nothing is hovered).
    readonly property var _hp: (chart.hoverIndex >= 0 && chart.hoverIndex < chart.points.length)
                               ? chart.points[chart.hoverIndex] : null

    // Hover hit-testing: find the nearest marker within a generous radius (bigger
    // than the 3.5px dot) and expose it as hoverIndex. NoButton so it never steals
    // clicks — it only tracks the cursor.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onPositionChanged: function (m) {
            var best = -1, bestD = 196;          // 14px pick radius, squared
            var ps = chart.points;
            for (var i = 0; i < ps.length; i++) {
                var dx = ps[i].px - m.x, dy = ps[i].py - m.y, d = dx * dx + dy * dy;
                if (d < bestD) { bestD = d; best = i; }
            }
            chart.hoverIndex = best;
        }
        onExited: chart.hoverIndex = -1
    }

    // Ring drawn around the hovered marker (a QML item, so hovering never forces a
    // full canvas repaint).
    Rectangle {
        visible: chart._hp !== null
        width: 13; height: 13; radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: chart._hp ? chart.seriesColor(chart._hp.algo) : "transparent"
        x: chart._hp ? chart._hp.px - width / 2 : 0
        y: chart._hp ? chart._hp.py - height / 2 : 0
    }

    // Tooltip card: algorithm, size N, and the exact metric value at that point.
    Rectangle {
        id: tip
        visible: chart._hp !== null
        z: 10
        radius: 6
        color: Qt.rgba(Theme.panelBg.r, Theme.panelBg.g, Theme.panelBg.b, 0.97)
        border.color: Theme.panelBorder; border.width: 1
        width: tipCol.implicitWidth + 20
        height: tipCol.implicitHeight + 16
        // Above-right of the point by default, clamped inside the chart bounds.
        x: chart._hp ? Math.max(0, Math.min(chart.width - width, chart._hp.px + 12)) : 0
        y: chart._hp ? Math.max(0, Math.min(chart.height - height, chart._hp.py - height - 10)) : 0

        Column {
            id: tipCol
            anchors.centerIn: parent
            spacing: 2
            Row {
                spacing: 6
                Rectangle {
                    width: 10; height: 10; radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: chart._hp ? chart.seriesColor(chart._hp.algo) : "transparent"
                }
                Text {
                    text: chart._hp ? chart._hp.algo : ""
                    color: Theme.textPrimary; font.pixelSize: 12; font.bold: true
                }
            }
            Text {
                text: chart._hp ? ("N = " + chart._hp.n) : ""
                color: Theme.textMuted; font.pixelSize: 11
            }
            Text {
                text: chart._hp ? ((chart.metric === "time" ? "mean " : "peak ")
                                   + chart.fmtHoverVal(chart._hp.val)) : ""
                color: Theme.textPrimary; font.pixelSize: 11
            }
        }
    }
}
