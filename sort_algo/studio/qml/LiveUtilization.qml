pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SortStudio

// Reusable live-utilisation monitor, pinned at the bottom of a control panel. Owns
// its own SystemMonitor (sampling only while `active`) and renders collapsible meters
// — System CPU / RAM / GPU and this app's CPU / RAM — each with a filled rolling
// sparkline. The caller persists `expanded` and flips it on toggled(). The GPU row
// hides itself when no GPU/PDH reading is available. Mirrors Graph Algorithm Studio's.
ColumnLayout {
    id: root
    property bool active: false
    property bool expanded: true
    signal toggled()

    spacing: 6

    SystemMonitor { id: sysmon; active: root.active }

    // One meter: label + value, a track with a filled rolling-history sparkline.
    component Meter: ColumnLayout {
        id: meter
        property string label: ""
        property real pct: 0            // 0..100
        property string detail: ""
        property color barColor: Theme.accent
        property var hist: []
        function push(v) {
            var a = meter.hist.slice();
            a.push(v);
            if (a.length > 60) a.shift();
            meter.hist = a;
            spark.requestPaint();
        }
        spacing: 2
        Layout.fillWidth: true
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Label { text: meter.label; color: Theme.textMuted; font.pixelSize: 11; Layout.fillWidth: true }
            Label { text: meter.detail; color: Theme.textMuted; font.pixelSize: 11 }
            Label { text: Math.round(meter.pct) + "%"; color: Theme.textPrimary; font.pixelSize: 11; font.bold: true }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 16
            radius: 3
            color: Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.06)
            clip: true
            Canvas {
                id: spark
                anchors.fill: parent
                renderStrategy: Canvas.Immediate
                renderTarget: Canvas.Image
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset();
                    var hh = meter.hist, n = hh.length;
                    if (n < 1) return;
                    var c = meter.barColor;
                    function px(i) { return width * i / 59; }                       // 60-sample window
                    function py(v) { return height - (Math.max(0, Math.min(100, v)) / 100) * height; }
                    ctx.beginPath();
                    ctx.moveTo(px(0), height);
                    for (var i = 0; i < n; i++) ctx.lineTo(px(i), py(hh[i]));
                    ctx.lineTo(px(n - 1), height);
                    ctx.closePath();
                    ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.22);
                    ctx.fill();
                    if (n >= 2) {
                        ctx.strokeStyle = c; ctx.lineWidth = 1.5; ctx.lineJoin = "round";
                        ctx.beginPath();
                        for (var j = 0; j < n; j++) {
                            if (j === 0) ctx.moveTo(px(j), py(hh[j])); else ctx.lineTo(px(j), py(hh[j]));
                        }
                        ctx.stroke();
                    }
                }
            }
        }
    }

    // Feed the sparklines each sample tick.
    Connections {
        target: sysmon
        function onSampled() {
            cpuMeter.push(sysmon.cpuPercent);
            ramMeter.push(sysmon.memPercent);
            if (sysmon.gpuPercent >= 0) gpuMeter.push(sysmon.gpuPercent);
            procCpuMeter.push(sysmon.procCpuPercent);
            procRamMeter.push(procRamMeter.pct);
        }
    }

    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.panelBorder }
    SectionHeader {
        title: "Live utilization"; expanded: root.expanded
        onToggled: root.toggled()
    }
    ColumnLayout {
        Layout.fillWidth: true; spacing: 6; visible: root.expanded

        Label { text: "System"; color: Theme.textMuted; font.pixelSize: 11 }
        Meter { id: cpuMeter; label: "CPU"; barColor: Theme.accent; pct: sysmon.cpuPercent }
        Meter {
            id: ramMeter; label: "RAM"; barColor: Theme.barCursor
            pct: sysmon.memPercent
            detail: sysmon.memUsedGb.toFixed(1) + " / " + sysmon.memTotalGb.toFixed(0) + " GB"
        }
        Meter {
            id: gpuMeter; label: "GPU"; barColor: Theme.barSorted
            pct: Math.max(0, sysmon.gpuPercent)
            visible: sysmon.gpuPercent >= 0     // hidden when no GPU/PDH reading
        }

        Label { text: "This app"; color: Theme.textMuted; font.pixelSize: 11; Layout.topMargin: 2 }
        Meter { id: procCpuMeter; label: "CPU"; barColor: Theme.accent; pct: sysmon.procCpuPercent }
        Meter {
            id: procRamMeter; label: "RAM"; barColor: Theme.barCursor
            pct: sysmon.memTotalGb > 0 ? sysmon.procMemMb / (sysmon.memTotalGb * 1024) * 100 : 0
            detail: sysmon.procMemMb.toFixed(0) + " MB"
        }
    }
}
