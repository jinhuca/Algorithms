pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SortStudio

// Pseudocode panel for the Visualizer: shows the current algorithm's steps with the
// line matching the current trace step highlighted, plus a one-line narration of
// what's happening right now. The per-algorithm `map` links a trace step kind
// (compare / swap / overwrite / cursor / read / pass_boundary) to a line index.
Rectangle {
    id: panel
    property var ctl

    color: Theme.panelBg
    border.color: Theme.panelBorder
    radius: 8
    clip: true

    readonly property var code: ({
        "Bubble": { lines: [
            "repeat for end = n … 2:",
            "  for i = 0 … end-2:",
            "    if a[i] > a[i+1]:",
            "      swap a[i], a[i+1]",
            "  mark a[end-1] sorted"],
            map: { "pass_boundary": 0, "compare": 2, "swap": 3, "mark_sorted": 4 } },
        "Selection": { lines: [
            "for i = 0 … n-2:",
            "  min = i",
            "  for j = i+1 … n-1:",
            "    if a[j] < a[min]: min = j",
            "  swap a[i], a[min]",
            "  mark a[i] sorted"],
            map: { "cursor": 1, "compare": 3, "swap": 4, "mark_sorted": 5 } },
        "Insertion": { lines: [
            "for i = 1 … n-1:",
            "  key = a[i]",
            "  j = i",
            "  while j>0 and a[j-1] > key:",
            "    a[j] = a[j-1];  j = j-1",
            "  a[j] = key"],
            map: { "cursor": 1, "compare": 3, "overwrite": 4 } },
        "Cocktail": { lines: [
            "lo = 0,  hi = n-1",
            "forward: for i = lo … hi-1:",
            "  if a[i] > a[i+1]: swap",
            "backward: for i = hi … lo+1:",
            "  if a[i] < a[i-1]: swap"],
            map: { "pass_boundary": 0, "compare": 1, "swap": 2 } },
        "Cycle": { lines: [
            "for start = 0 … n-2:",
            "  item = a[start]",
            "  pos = start + #elements < item",
            "  if pos == start: continue",
            "  place item at pos (skip dups)",
            "  follow the cycle until closed"],
            map: { "cursor": 1, "compare": 2, "overwrite": 4, "mark_sorted": 0 } },
        "Merge": { lines: [
            "split the range in half",
            "sort each half (recursively)",
            "merge: compare the two heads",
            "  take the smaller into buf",
            "copy buf back into the array"],
            map: { "compare": 2, "overwrite": 4, "mark_sorted": 0 } },
        "Quick": { lines: [
            "pivot = a[hi]",
            "for j = lo … hi-1:",
            "  if a[j] < pivot: swap a[i++],a[j]",
            "swap pivot into place a[i]",
            "recurse on left and right"],
            map: { "cursor": 0, "compare": 1, "swap": 2, "mark_sorted": 3 } },
        "Heap": { lines: [
            "build a max-heap",
            "for end = n-1 … 1:",
            "  swap a[0], a[end]",
            "  mark a[end] sorted",
            "  sift-down: compare kids, swap"],
            map: { "compare": 4, "swap": 2, "mark_sorted": 3 } },
        "Shell": { lines: [
            "for gap = n/3 … 1:",
            "  for i = gap … n-1:",
            "    key = a[i];  j = i",
            "    while j>=gap and a[j-gap]>key:",
            "      a[j] = a[j-gap];  j -= gap",
            "    a[j] = key"],
            map: { "pass_boundary": 0, "cursor": 2, "compare": 3, "overwrite": 4 } },
        "Radix": { lines: [
            "key[i] = integer key of a[i]",
            "for each byte, LSB → MSB:",
            "  count elements per bucket",
            "  distribute stably by that byte",
            "  write the buckets back in order"],
            map: { "read": 0, "pass_boundary": 1, "overwrite": 4, "mark_sorted": 1 } },
        "Counting": { lines: [
            "tally occurrences of each key",
            "for each key in ascending order:",
            "  write the key (count) times"],
            map: { "read": 0, "overwrite": 2, "mark_sorted": 1 } },
        "Bucket": { lines: [
            "find the value range [min, max]",
            "scatter values into n buckets",
            "insertion-sort each bucket",
            "concatenate buckets in order"],
            map: { "read": 0, "overwrite": 3, "mark_sorted": 0 } }
    })

    readonly property var current: panel.code[panel.ctl.algorithm]
    readonly property int activeLine: {
        if (panel.ctl.stepLine >= 0) return panel.ctl.stepLine;   // line-exact, from the core trace
        if (!current) return -1;                                   // fallback: map the step kind
        var m = current.map[panel.ctl.stepKind];
        return (m === undefined) ? -1 : m;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        Label {
            text: panel.ctl.algorithm + " sort"
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

        // Live narration of the current step.
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
                text: panel.ctl.atEnd && panel.ctl.stepCount > 0
                      ? "Done — array is sorted."
                      : (panel.ctl.note.length ? panel.ctl.note : "Press Run to start.")
                color: Theme.textPrimary; font.pixelSize: 12
                wrapMode: Text.WordWrap; verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
