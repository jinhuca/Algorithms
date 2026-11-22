pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SearchStudio

// Pseudocode panel for the Visualizer: shows the current algorithm's steps with the
// line matching the current trace step highlighted, plus a one-line narration. The
// per-algorithm `map` links a trace step kind (probe / mid / lo_bound / hi_bound /
// eliminate / found) to a line index; the core trace also carries an exact line.
Rectangle {
    id: panel
    property var ctl

    color: Theme.panelBg
    border.color: Theme.panelBorder
    radius: 8
    clip: true

    readonly property var code: ({
        "Linear": { lines: [
            "for i = 0 … n-1:",
            "  if a[i] == target: return i",
            "return NOT FOUND"],
            map: { "probe": 0, "found": 1, "not_found": 2 } },
        "Sentinel": { lines: [
            "append target as a guard at a[n]",
            "i = 0",
            "while a[i] != target: i = i + 1",
            "return i < n ? i : NOT FOUND"],
            map: { "probe": 2, "found": 3, "not_found": 3 } },
        "Binary": { lines: [
            "lo = 0,  hi = n",
            "while lo < hi:",
            "  mid = (lo + hi) / 2",
            "  if a[mid] < target: lo = mid+1",
            "  elif a[mid] > target: hi = mid",
            "  else: return mid",
            "return NOT FOUND"],
            map: { "mid": 2, "probe": 2, "lo_bound": 3, "hi_bound": 4, "eliminate": 3, "found": 5, "not_found": 6 } },
        "Ternary": { lines: [
            "while window > 2:",
            "  m1 = lo + len/3",
            "  m2 = hi - len/3",
            "  if target < a[m1]: keep left",
            "  elif a[m2] < target: keep right",
            "  else: keep middle third",
            "scan the last 1–2 elements"],
            map: { "mid": 1, "probe": 1, "hi_bound": 3, "lo_bound": 4, "eliminate": 5, "found": 5, "not_found": 6 } },
        "Jump": { lines: [
            "block = √n",
            "jump by block while a[last] < target",
            "  (skip a whole block each step)",
            "linear-scan inside the final block",
            "return the match, or NOT FOUND"],
            map: { "probe": 1, "eliminate": 2, "found": 3, "not_found": 4 } },
        "Exponential": { lines: [
            "if a[0] == target: return 0",
            "bound = 1",
            "while a[bound] < target: bound *= 2",
            "binary-search [bound/2, bound]",
            "return the match, or NOT FOUND"],
            map: { "probe": 2, "eliminate": 2, "lo_bound": 3, "hi_bound": 3, "mid": 3, "found": 1, "not_found": 4 } },
        "Interpolation": { lines: [
            "while target in [a[lo], a[hi]]:",
            "  pos = lo + (target-a[lo])/slope",
            "  if a[pos] == target: return pos",
            "  if a[pos] < target: lo = pos+1",
            "  else: hi = pos-1",
            "return NOT FOUND"],
            map: { "mid": 1, "probe": 1, "found": 2, "lo_bound": 3, "hi_bound": 4, "eliminate": 3, "not_found": 5 } },
        "Fibonacci": { lines: [
            "pick the smallest Fib ≥ n",
            "while fib > 1:",
            "  probe offset + Fib(k-2)",
            "  move the window down the Fibs",
            "check the last candidate",
            "return the match, or NOT FOUND"],
            map: { "probe": 2, "eliminate": 3, "found": 4, "not_found": 5 } }
    })

    readonly property var current: panel.code[panel.ctl.algorithm]
    readonly property int activeLine: {
        if (panel.ctl.stepLine >= 0) return panel.ctl.stepLine;   // line-exact, from the core trace
        if (!current) return -1;
        var m = current.map[panel.ctl.stepKind];
        return (m === undefined) ? -1 : m;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        Label {
            text: panel.ctl.algorithm + " search"
            color: Theme.textPrimary; font.pixelSize: 15; font.bold: true
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.panelBorder }

        Column {
            Layout.fillWidth: true
            spacing: 1
            Repeater {
                model: panel.current ? panel.current.lines : []
                delegate: Rectangle {
                    required property int index
                    required property string modelData
                    width: parent.width
                    implicitHeight: lineLabel.implicitHeight + 6
                    radius: 4
                    color: index === panel.activeLine
                           ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                           : "transparent"
                    Label {
                        id: lineLabel
                        anchors.verticalCenter: parent.verticalCenter
                        x: 6
                        width: parent.width - 12
                        text: modelData
                        font.family: "Consolas, monospace"
                        font.pixelSize: 12
                        color: index === panel.activeLine ? Theme.textPrimary : Theme.textMuted
                        wrapMode: Text.NoWrap
                        elide: Text.ElideRight
                    }
                    Behavior on color { ColorAnimation { duration: 90 } }
                }
            }
        }

        Item { Layout.fillHeight: true }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: narr.implicitHeight + 16
            radius: 6
            color: Theme.canvasBg
            border.color: Theme.panelBorder
            Label {
                id: narr
                anchors.fill: parent
                anchors.margins: 8
                text: panel.ctl.finished
                      ? panel.ctl.result
                      : (panel.ctl.note.length ? panel.ctl.note : "Press Run to start.")
                color: Theme.textPrimary; font.pixelSize: 12
                wrapMode: Text.WordWrap; verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
