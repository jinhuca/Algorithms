pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import SortStudio
import UiKit

// Analyzer workspace: configure a benchmark sweep (algorithms × sizes for one input
// distribution), run it on a worker thread, and stream the timings + comparison/swap
// counts into a results table and a time-vs-N scaling chart. Export to CSV. A
// resizable split separates the config panel from the results. Each algorithm's
// Big-O complexity is shown under its checkbox in the config panel (not as a table
// column), so the results table stays compact and its numeric columns line up.
Item {
    id: page
    property var ctl
    property var win

    // Which algorithms are ticked — a { name: bool } map so the grouped (nested)
    // checkboxes don't need item-tree traversal to read/set selection.
    property var selected: page.initSelected()
    function initSelected() {
        var m = {};
        var all = page.ctl.algorithms;
        for (var i = 0; i < all.length; i++) m[all[i]] = true;
        return m;
    }
    function setSel(name, on) {
        var m = Object.assign({}, page.selected);
        m[name] = on;
        page.selected = m;
    }
    function selectedAlgorithms() {
        var out = [];
        var all = page.ctl.algorithms;
        for (var i = 0; i < all.length; i++) if (page.selected[all[i]]) out.push(all[i]);
        return out;
    }
    // Deep-link entry from the Knowledge base: select only this algorithm.
    function selectAlgo(name) {
        var m = {};
        var all = page.ctl.algorithms;
        for (var i = 0; i < all.length; i++) m[all[i]] = (all[i] === name);
        page.selected = m;
    }
    function parsedSizes() {
        var out = [];
        var parts = sizesField.text.split(/[,\s]+/);
        for (var i = 0; i < parts.length; i++) {
            var n = parseInt(parts[i]);
            if (!isNaN(n) && n > 0) out.push(n);
        }
        return out;
    }

    SplitView {
        anchors.fill: parent
        orientation: Qt.Horizontal

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

        // ---- config panel ----
        Rectangle {
            SplitView.preferredWidth: 300
            SplitView.minimumWidth: 260
            color: Theme.panelBg; border.color: Theme.panelBorder; radius: 8
            clip: true
            Flickable {
                anchors.fill: parent
                anchors.margins: 14
                contentWidth: width
                contentHeight: cfgCol.implicitHeight
                clip: true
                ScrollBar.vertical: ScrollBar { id: cfgBar; policy: ScrollBar.AsNeeded; width: 10 }
                ColumnLayout {
                id: cfgCol
                width: parent.width - cfgBar.width - 4   // dedicated gutter for the scrollbar
                spacing: 10

                Label { text: "Algorithms"; color: Theme.textMuted; font.pixelSize: 12 }
                // Grouped by complexity category (O(n²) / O(n log n)); each algorithm
                // carries its Big-O under the checkbox.
                Repeater {
                    model: page.ctl.categories
                    delegate: ColumnLayout {
                        required property string modelData
                        readonly property string catName: modelData
                        Layout.fillWidth: true
                        spacing: 2

                        Label {
                            text: catName
                            color: Theme.textPrimary; font.pixelSize: 12; font.bold: true
                            Layout.topMargin: 4
                        }
                        Repeater {
                            model: page.ctl.algorithmsIn(catName)
                            // One compact line: checkbox + name on the left, the Big-O
                            // description right-aligned (elides if the panel is narrow).
                            delegate: RowLayout {
                                required property string modelData
                                readonly property string algoName: modelData
                                Layout.fillWidth: true
                                Layout.leftMargin: 6
                                spacing: 6
                                CheckBox {
                                    id: cb
                                    text: algoName
                                    checked: page.selected[algoName] === true
                                    onToggled: page.setSel(algoName, checked)
                                    contentItem: Label { text: cb.text; color: Theme.textPrimary; font.pixelSize: 13
                                                         leftPadding: cb.indicator.width + 6; verticalAlignment: Text.AlignVCenter }
                                }
                                Label {
                                    text: page.ctl.complexityOf(algoName)
                                    color: Theme.textMuted; font.pixelSize: 11
                                    horizontalAlignment: Text.AlignRight
                                    verticalAlignment: Text.AlignVCenter
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                Label { text: "Input distribution"; color: Theme.textMuted; font.pixelSize: 12 }
                UiComboBox {
                    id: distCombo
                    Layout.fillWidth: true
                    model: page.ctl.distributions
                }

                Label { text: "Sizes (N)"; color: Theme.textMuted; font.pixelSize: 12 }
                TextField {
                    id: sizesField
                    Layout.fillWidth: true
                    text: "500, 1000, 2000, 4000, 8000"
                    placeholderText: "e.g. 500, 1000, 2000"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Label { text: "Reps"; color: Theme.textMuted; font.pixelSize: 12 }
                    SpinBox { id: repsSpin; from: 1; to: 50; value: 5
                              Layout.fillWidth: true; Layout.preferredWidth: 60 }
                    Label { text: "Seed"; color: Theme.textMuted; font.pixelSize: 12 }
                    SpinBox { id: seedSpin; from: 0; to: 99999; value: 1; editable: true
                              Layout.fillWidth: true; Layout.preferredWidth: 60 }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    UiButton {
                        Layout.fillWidth: true
                        text: page.ctl.running ? "Cancel" : "Run"
                        highlighted: !page.ctl.running
                        onClicked: {
                            if (page.ctl.running) { page.ctl.cancel(); return; }
                            page.ctl.run({
                                algorithms: page.selectedAlgorithms(),
                                distribution: distCombo.currentText,
                                sizes: page.parsedSizes(),
                                reps: repsSpin.value,
                                seed: seedSpin.value,
                                countOps: true
                            });
                        }
                    }
                    UiButton { text: "Clear"; enabled: !page.ctl.running; onClicked: page.ctl.clearResults() }
                }
                UiButton {
                    Layout.fillWidth: true
                    text: "Export CSV…"
                    enabled: page.ctl.results.length > 0
                    onClicked: csvDialog.open()
                }

                ProgressBar {
                    Layout.fillWidth: true
                    from: 0; to: 1; value: page.ctl.progress
                    visible: page.ctl.running
                }
                Label {
                    Layout.fillWidth: true
                    text: page.ctl.status
                    color: Theme.textMuted
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
                // Live resource use (samples only while the Analyzer is on screen).
                LiveUtilization {
                    Layout.fillWidth: true
                    active: page.visible
                    expanded: page.win ? page.win.monitorExpanded : true
                    onToggled: if (page.win) page.win.monitorExpanded = !page.win.monitorExpanded
                }
                }
            }
        }

        // ---- results: table (top) + scaling chart (bottom), vertically resizable ----
        SplitView {
            SplitView.fillWidth: true
            SplitView.minimumWidth: 360
            orientation: Qt.Vertical

            handle: Rectangle {
                id: vHandle
                implicitWidth: 14; implicitHeight: 14
                color: "transparent"
                readonly property bool active: SplitHandle.hovered || SplitHandle.pressed
                readonly property bool held: SplitHandle.pressed
                Rectangle {
                    anchors.centerIn: parent
                    width: 30; height: 2; radius: 1
                    color: vHandle.held ? Theme.accent : (vHandle.active ? Theme.panelBorder : "transparent")
                }
            }

            Rectangle {
                id: resultsBox
                SplitView.fillHeight: true
                SplitView.minimumHeight: 140
                color: Theme.panelBg; border.color: Theme.panelBorder; radius: 8
                clip: true

                // One shared column model, used identically by the header and every
                // row, so the columns line up. `frac`s are fractions of the table
                // width and sum to 1.
                readonly property var columns: [
                    { key: "algorithm", title: "Algorithm",   frac: 0.21, align: Text.AlignLeft },
                    { key: "n",         title: "N",            frac: 0.08, align: Text.AlignRight },
                    { key: "medianMs",  title: "Median ms",    frac: 0.13, align: Text.AlignRight },
                    { key: "cpuMs",     title: "CPU ms",       frac: 0.12, align: Text.AlignRight },
                    { key: "memBytes",  title: "Peak mem",     frac: 0.15, align: Text.AlignRight },
                    { key: "compares",  title: "Comparisons",  frac: 0.16, align: Text.AlignRight },
                    { key: "swaps",     title: "Swaps",        frac: 0.15, align: Text.AlignRight }
                ]
                function fmtBytes(b) {
                    if (b <= 0) return "—";
                    if (b < 1024) return Math.round(b) + " B";
                    if (b < 1024 * 1024) return (b / 1024).toFixed(1) + " KB";
                    return (b / (1024 * 1024)).toFixed(2) + " MB";
                }
                function cellText(key, r) {
                    if (key === "medianMs") return Number(r[key]).toFixed(3);
                    if (key === "cpuMs") { var c = Number(r[key]); return c < 0 ? "—" : c.toFixed(3); }
                    if (key === "memBytes") return resultsBox.fmtBytes(Number(r[key]));
                    if (key === "compares" || key === "swaps") return Math.round(r[key]).toLocaleString(Qt.locale(), "f", 0);
                    return r[key];
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    // header
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 20
                        Row {
                            id: headerCells
                            x: 0; height: parent.height
                            width: parent.width - (tblBar.width + 4)   // match the rows' scrollbar gutter
                            Repeater {
                                model: resultsBox.columns
                                delegate: Label {
                                    required property var modelData
                                    width: Math.round(headerCells.width * modelData.frac)
                                    text: modelData.title
                                    color: Theme.textMuted
                                    font.pixelSize: 12; font.bold: true
                                    horizontalAlignment: modelData.align
                                    leftPadding: modelData.align === Text.AlignLeft ? 2 : 0
                                    rightPadding: modelData.align === Text.AlignRight ? 8 : 0
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.panelBorder }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: page.ctl.resultsModel
                        ScrollBar.vertical: ScrollBar { id: tblBar; width: 10 }
                        delegate: Column {
                            id: rowCol
                            required property var rowData
                            required property bool groupStart
                            width: (ListView.view ? ListView.view.width : 0) - (tblBar.width + 4)
                            Rectangle { visible: rowCol.groupStart; width: parent.width; height: 1; color: Theme.panelBorder }
                            Row {
                                id: rowCells
                                width: parent.width
                                height: 22
                                Repeater {
                                    model: resultsBox.columns
                                    delegate: Label {
                                        required property var modelData
                                        width: Math.round(rowCells.width * modelData.frac)
                                        height: 22
                                        text: resultsBox.cellText(modelData.key, rowCol.rowData)
                                        // Row text in the algorithm's series colour, matching the
                                        // chart legend/lines (same mapping as ScalingChart).
                                        color: scalingChart.seriesColor(rowCol.rowData.algorithm)
                                        font.pixelSize: 12
                                        horizontalAlignment: modelData.align
                                        verticalAlignment: Text.AlignVCenter
                                        leftPadding: modelData.align === Text.AlignLeft ? 2 : 0
                                        rightPadding: modelData.align === Text.AlignRight ? 8 : 0
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ScalingChart {
                id: scalingChart
                SplitView.preferredHeight: 260
                SplitView.minimumHeight: 140
                results: page.ctl.results
                algoOrder: page.ctl.algorithms      // fixed per-algorithm colour mapping
            }
        }
    }

    FileDialog {
        id: csvDialog
        title: "Export results as CSV"
        fileMode: FileDialog.SaveFile
        nameFilters: ["CSV files (*.csv)"]
        defaultSuffix: "csv"
        onAccepted: page.ctl.exportCsv(selectedFile)
    }
}
