pragma ComponentBehavior: Bound
import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import GraphVis
import UiKit

// Graph Algorithm Analyzer — headless benchmark workspace. Left: a config panel
// (algorithms, graph family, sizes, options). Right: a live results table. The
// AnalyzerController runs the sweep on a worker thread (no rendering), streaming
// rows back as each (algorithm × size) cell finishes. See AddAnalyser.md.
Item {
    id: page

    AnalyzerController { id: analyzer }

    // Collapse/expand state of the Benchmark-panel sections (persisted below).
    property bool secAlgorithms: true
    property bool secGraphFamily: true
    property bool secSizes: true
    property bool secOptions: true
    property bool secMonitor: true

    // Persist the benchmark config across sessions, in its own QSettings group so
    // it can't clash with the visualizer's keys. (Results themselves aren't saved.)
    Settings {
        id: settings
        category: "analyzer"
        property alias secAlgorithms: page.secAlgorithms
        property alias secGraphFamily: page.secGraphFamily
        property alias secSizes: page.secSizes
        property alias secOptions: page.secOptions
        property alias secMonitor: page.secMonitor
        property alias selectedAlgos: page.selectedAlgos
        property alias family: familyBox.currentIndex
        property alias sizes: sizesField.text
        // Size-profile controls (the sizes list is generated from these; see below).
        property alias sizeProfile: profileBox.currentIndex
        property alias sizeStart: startSpin.value
        property alias sizeStop: stopSpin.value
        property alias sizeStep: stepSpin.value
        property alias sizePoints: pointsSpin.value
        property alias directed: directedBox.checked
        property alias weighted: weightedBox.checked
        property alias avgDegree: degSpin.value
        property alias reps: repsSpin.value
        property alias seed: seedSpin.value
        property alias metric: scalingChart.metric
        // Opaque SplitView.saveState() blob — the table/chart divider position, so
        // the user's chosen heights survive a restart (see resultsSplit below).
        property var resultsSplitState
        // SplitView.saveState() blob for the Benchmark-panel ↔ results divider width.
        property var resultsPanelSplitState
        // Per-column widths of the results table, so drag-resized columns persist.
        property var resultsColWidths
    }

    // Result-table columns, grouped by meaning: [name] | [loads: N,M] | [ops] |
    // [time] | [resources]. `groupStart: true` marks the first column of a group and
    // draws a vertical separator on its left edge (see the header/row delegates).
    // Each has a key into a result row, header title, width, value format, and a
    // header hover tip.
    readonly property var columns: [
        { key: "algorithm", title: "Algorithm", w: 100, kind: "text",   tip: "The benchmarked algorithm" },
        { key: "n",         title: "N",         w: 70,  kind: "text",   groupStart: true, tip: "Vertices in the generated graph (graph order)" },
        { key: "m",         title: "M",         w: 85,  kind: "text",   tip: "Edges in the generated graph (graph size)" },
        { key: "ops",       title: "ops",       w: 95,  kind: "text",   groupStart: true, tip: "Total traced operations from one untimed counted run" },
        { key: "minMs",     title: "min",       w: 85,  kind: "ms",     groupStart: true, tip: "Fastest of the timed repetitions, in milliseconds" },
        { key: "medianMs",  title: "median",    w: 85,  kind: "ms",     tip: "Median run time of the timed repetitions, in milliseconds" },
        { key: "meanMs",    title: "mean",      w: 85,  kind: "ms",     tip: "Mean run time of the timed repetitions, in milliseconds" },
        { key: "stddevMs",  title: "σ",         w: 70,  kind: "ms",     tip: "Standard deviation of the timed run times, in milliseconds" },
        { key: "memBytes",  title: "peak mem",  w: 95,  kind: "bytes",  groupStart: true, tip: "Peak extra heap used by a single run (the algorithm's working set, excluding the graph)" },
        { key: "footBytes", title: "RAM",       w: 130, kind: "ram",    tip: "This cell's total memory footprint (graph + run) and its share of installed RAM. ⚠ marks a run whose footprint exceeded most of free RAM — its timings likely include disk paging and are unreliable." },
        { key: "cpuPct",    title: "CPU %",     w: 70,  kind: "cpuPct", tip: "CPU time ÷ wall time over the timed window, capped at 100% (these algorithms are single-threaded). ~100% = CPU-bound; well below 100% means the run stalled, e.g. paging. The CSV keeps the raw uncapped value." },
        { key: "cpuMs",     title: "CPU (ms)",  w: 85,  kind: "cpuMs",  tip: "Average CPU time consumed per run, in milliseconds. May read 0 for sub-millisecond algorithms due to OS thread-time granularity." }
    ]
    // Live per-column widths (seeded from each column's default `w`). Mutable so the
    // header's drag handles can resize columns; the header and every data row both
    // read widths from here, so they stay aligned. Reassign the whole array to
    // notify (mutating one element in place wouldn't trigger bindings).
    property var colWidths: page.columns.map(function (c) { return c.w; })
    function setColWidth(i, w) {
        var a = page.colWidths.slice();
        a[i] = Math.max(40, w);          // keep a usable minimum
        page.colWidths = a;
    }
    function colKeys() { return page.columns.map(function (c) { return c.key; }); }
    // Restore persisted widths only if saved against the SAME ordered column set
    // (so a reorder/rename/add safely falls back to the default widths).
    Component.onCompleted: {
        var saved = settings.resultsColWidths;
        if (saved && saved.keys && saved.widths
                && saved.keys.join(",") === page.colKeys().join(","))
            page.colWidths = saved.widths.slice();
        // Regenerate the sizes preview from the restored profile/params (Custom keeps
        // its restored free text).
        page.recomputeSizes();
    }
    Component.onDestruction: settings.resultsColWidths = { keys: page.colKeys(), widths: page.colWidths }
    // Theoretical worst-case time complexity (binary-heap Dijkstra/Prim), shown
    // beside each row so measured timings can be read against the expected curve.
    readonly property var bigOTime: ({
        "BFS": "O(V + E)",
        "DFS": "O(V + E)",
        "Dijkstra": "O((V+E) log V)",
        "Bellman-Ford": "O(V·E)",
        "Kruskal": "O(E log E)",
        "Prim": "O((V+E) log V)"
    })
    // One-line description per graph family (shown on hover in the dropdown).
    readonly property var familyTips: ({
        "random":     "Erdős–Rényi G(n, m): n vertices with random edges to reach the target average degree. Sparse, unstructured.",
        "grid":       "4-neighbour square lattice (n rounded to the nearest square). Regular structure, large diameter.",
        "scale-free": "Barabási–Albert preferential attachment: a few high-degree hubs, like real-world networks.",
        "complete":   "K_n: every pair of vertices connected. Dense — Θ(n²) edges; the memory-stress case."
    })
    function humanBytes(n) {
        if (n < 1024) return n + " B";
        if (n < 1024 * 1024) return (n / 1024).toFixed(1) + " KB";
        return (n / (1024 * 1024)).toFixed(2) + " MB";
    }
    function fmt(row, col) {
        if (col.kind === "ram") {                              // footprint bytes · % of RAM
            const fb = row.footBytes, p = row.memPct;
            if (fb === undefined || p === undefined || p < 0) return "—";
            return (row.swapRisk ? "⚠ " : "") + page.humanBytes(fb) + " · " + Math.round(p * 100) + "%";
        }
        if (col.kind === "cpuPct") {
            const c = row.cpuPct;
            // Clamp to 100%: these algorithms are single-threaded, so values above
            // 100% are only GetThreadTimes' coarse (~15.6 ms) granularity overshooting
            // on short runs. The meaningful signal is a drop below 100% (a stall).
            return (c === undefined || c < 0) ? "—" : Math.min(100, Math.round(c)) + "%";
        }
        if (col.kind === "cpuMs") {
            const c = row.cpuMs;
            return (c === undefined || c < 0) ? "—" : Number(c).toFixed(3);
        }
        const v = row[col.key];
        if (col.kind === "ms") return Number(v).toFixed(3);
        if (col.kind === "bytes") return page.humanBytes(v);
        return "" + v;
    }
    // Parse the sizes text into { valid: [int…], bad: [token…] }. Tolerant of any
    // separator run (comma, whitespace, newline, semicolon) so pasted/loaded text in
    // various shapes works; a token is valid only if it's a plain positive integer
    // (so "12abc" is reported as bad rather than silently truncated to 12).
    function sizesStats(t) {
        var toks = (t || "").split(/[\s,;]+/).filter(function (s) { return s.length > 0; });
        var valid = [], bad = [];
        for (var i = 0; i < toks.length; i++) {
            if (/^\d+$/.test(toks[i]) && parseInt(toks[i], 10) > 0) valid.push(parseInt(toks[i], 10));
            else bad.push(toks[i]);
        }
        return { valid: valid, bad: bad };
    }
    function parsedSizes() { return page.sizesStats(sizesField.text).valid; }
    // Live feedback for the field: count of valid sizes, and any ignored tokens.
    function sizesHint(t) {
        var s = page.sizesStats(t);
        if (s.valid.length === 0) return "⚠ No valid sizes — enter positive integers (e.g. 100, 200, 500).";
        var msg = s.valid.length + (s.valid.length === 1 ? " size" : " sizes");
        if (s.bad.length) msg += "   ·   ⚠ ignored " + s.bad.length + ": " + s.bad.slice(0, 4).join(", ") + (s.bad.length > 4 ? " …" : "");
        return msg;
    }

    // ---- size profiles ------------------------------------------------------
    // The sizes list is generated into sizesField (the single source of truth that
    // parsedSizes()/doRun() read) from a profile + a few parameters, so users pick a
    // shape instead of hand-typing a comma list. "Custom" unlocks free text editing.
    readonly property int sizeMaxCount: 500   // guard against a runaway linear sweep

    // Round x to a tidy 1 / 2 / 5 × 10ᵏ value (same idea as ScalingChart.niceCeil).
    function tidySize(x) {
        if (x <= 0) return 1;
        var e = Math.floor(Math.log(x) / Math.LN10);
        var base = Math.pow(10, e);
        var f = x / base;
        var nf = f < 1.5 ? 1 : f < 3.5 ? 2 : f < 7.5 ? 5 : 10;
        return Math.round(nf * base);
    }
    function genLinear(start, step, stop) {
        var out = [];
        if (step <= 0 || stop < start) return [start];
        for (var v = start; v <= stop && out.length < page.sizeMaxCount; v += step) out.push(v);
        return out;
    }
    function genGeometric(start, stop, points) {
        if (start <= 0 || points < 2) return [start];
        if (stop <= start) return [start];
        var ratio = Math.pow(stop / start, 1 / (points - 1));
        var out = [];
        for (var i = 0; i < points; i++) {
            var v = page.tidySize(start * Math.pow(ratio, i));
            if (out.length === 0 || v !== out[out.length - 1]) out.push(v);   // dedupe
        }
        return out;
    }
    // Regenerate sizesField for the active generated profile; no-op for "Custom".
    function recomputeSizes() {
        var p = profileBox.currentText;
        if (p === "Custom") return;
        var list = (p === "Large range")
            ? page.genGeometric(stopSpin.value >= startSpin.value ? startSpin.value : stopSpin.value,
                                Math.max(startSpin.value, stopSpin.value), pointsSpin.value)
            : page.genLinear(startSpin.value, stepSpin.value, stopSpin.value);
        sizesField.text = list.join(", ");
    }
    // Custom-mode generators: build a linear range from Start/Step/Stop and either
    // replace the field (Set) or merge it into the current list, deduped + sorted (Add),
    // so users can compose several ranges into one Custom list.
    function customSet() {
        sizesField.text = page.genLinear(startSpin.value, stepSpin.value, stopSpin.value).join(", ");
    }
    function customAdd() {
        var merged = page.parsedSizes().concat(page.genLinear(startSpin.value, stepSpin.value, stopSpin.value));
        merged = merged.filter(function (v, i, a) { return a.indexOf(v) === i; })   // dedupe
                       .sort(function (a, b) { return a - b; })                     // ascending
                       .slice(0, page.sizeMaxCount);
        sizesField.text = merged.join(", ");
    }

    // Selected algorithms as a comma-separated string — the single source of truth
    // for the checkboxes, so the selection can be persisted (see Settings below).
    property string selectedAlgos: "BFS,Dijkstra"
    function isAlgoSel(a) { return ("," + selectedAlgos + ",").indexOf("," + a + ",") >= 0; }
    function setAlgoSel(a, on) {
        var list = selectedAlgos.length ? selectedAlgos.split(",") : [];
        var i = list.indexOf(a);
        if (on && i < 0) list.push(a);
        else if (!on && i >= 0) list.splice(i, 1);
        selectedAlgos = list.join(",");
    }

    // Ensure an algorithm is checked (used by the Knowledge page's "Benchmark" deep
    // link); leaves the user's other selections intact.
    function selectAlgo(a) { page.setAlgoSel(a, true); }

    function doRun() {
        var algos = page.selectedAlgos.length ? page.selectedAlgos.split(",") : [];
        analyzer.run({
            algorithms: algos,
            family: familyBox.currentText,
            sizes: page.parsedSizes(),
            directed: directedBox.checked,
            weighted: weightedBox.checked,
            avgDegree: degSpin.value,
            reps: repsSpin.value,
            seed: seedSpin.value,
            countOps: true
        });
    }

    // Benchmark panel (left) and results (right) in a horizontal SplitView so the
    // panel can be dragged wider/narrower. Handle style mirrors the other splitters.
    SplitView {
        id: panelSplit
        anchors.fill: parent
        orientation: Qt.Horizontal

        Component.onCompleted: if (settings.resultsPanelSplitState) restoreState(settings.resultsPanelSplitState)
        Component.onDestruction: settings.resultsPanelSplitState = saveState()

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
        Frame {
            SplitView.preferredWidth: 320
            SplitView.minimumWidth: 260
            background: Rectangle { color: Theme.panelBg; border.color: Theme.panelBorder; radius: 8 }

            // Scrollable config on top; the live-utilisation monitor pinned below it so
            // it stays visible regardless of scroll position.
            ColumnLayout {
                anchors.fill: parent
                spacing: 8

            ScrollView {
                id: cfgScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth
                ScrollBar.vertical: ScrollBar { id: cfgVBar; policy: ScrollBar.AsNeeded }

                ColumnLayout {
                    // Leave a gutter for the vertical scrollbar (an overlay otherwise) so
                    // it never sits on top of the controls; full width when not scrolling.
                    width: cfgScroll.availableWidth - (cfgVBar.visible ? cfgVBar.width : 0)
                    spacing: 10

                    Label { text: "Benchmark"; font.bold: true; font.pixelSize: 17; color: Theme.textPrimary }

                    // ---- Algorithms (collapsible) ----
                    SectionHeader {
                        title: "Algorithms"; expanded: page.secAlgorithms
                        onToggled: page.secAlgorithms = !page.secAlgorithms
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 4; visible: page.secAlgorithms
                        Repeater {
                            id: algoRepeater
                            model: analyzer.algorithms
                            delegate: RowLayout {
                                id: algoRow
                                required property string modelData
                                Layout.fillWidth: true
                                spacing: 6
                                CheckBox {
                                    text: algoRow.modelData
                                    checked: page.isAlgoSel(algoRow.modelData)
                                    onToggled: page.setAlgoSel(algoRow.modelData, checked)
                                }
                                // Time complexity shown beside the name (was its own table column).
                                Label {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignRight
                                    text: page.bigOTime[algoRow.modelData] || ""
                                    color: Theme.textMuted
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    // ---- Graph family (collapsible) ----
                    SectionHeader {
                        title: "Graph family"; expanded: page.secGraphFamily
                        onToggled: page.secGraphFamily = !page.secGraphFamily
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 6; visible: page.secGraphFamily
                        UiComboBox {
                            id: familyBox
                            Layout.fillWidth: true
                            model: analyzer.families
                            // Override the popup row delegate (mirrors UiComboBox's own
                            // styling) to add a hover tip describing each graph family.
                            delegate: ItemDelegate {
                                id: famRow
                                required property var modelData
                                required property int index
                                width: familyBox.width
                                height: Math.round(Metrics.controlHeight * 1.4)
                                padding: 0
                                highlighted: familyBox.highlightedIndex === famRow.index
                                contentItem: Text {
                                    leftPadding: Metrics.spacingLarge
                                    rightPadding: Metrics.spacingLarge
                                    text: famRow.modelData
                                    font.pixelSize: Typography.body
                                    font.family: Typography.family
                                    color: famRow.highlighted ? UiPalette.selectionText : UiPalette.textPrimary
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                                background: Rectangle {
                                    color: famRow.highlighted ? UiPalette.selection : "transparent"
                                }
                                HoverHandler { id: famHover }
                                ToolTip.visible: famHover.hovered && !!page.familyTips[famRow.modelData]
                                ToolTip.text: page.familyTips[famRow.modelData] || ""
                                ToolTip.delay: 400
                            }
                        }
                    }

                    // ---- Sizes (collapsible) ----
                    SectionHeader {
                        title: "Sizes (N)"; expanded: page.secSizes
                        onToggled: page.secSizes = !page.secSizes
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 8; visible: page.secSizes

                        // Profile picker — generates the sizes list from a few parameters
                        // (Custom = hand-edit). See recomputeSizes() / genLinear / genGeometric.
                        UiComboBox {
                            id: profileBox
                            Layout.fillWidth: true
                            model: ["Small steps", "Large range", "Custom"]
                            onActivated: page.recomputeSizes()
                            ToolTip.visible: profileBox.hovered
                            ToolTip.text: "Small steps: linear ramp (Start/Step/Stop). Large range: log-spaced (Start/Stop/Points). Custom: type the list yourself."
                        }

                        // Start/Stop always; Step shown for "Small steps" and as the Custom
                        // generator; Points shown for "Large range".
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 8
                            rowSpacing: 6

                            Label { text: "Start"; color: Theme.textPrimary; font.pixelSize: 13 }
                            SpinBox {
                                id: startSpin; from: 0; to: 1000000; value: 100; stepSize: 100
                                editable: true; Layout.fillWidth: true
                                onValueChanged: page.recomputeSizes()
                            }
                            Label { text: "Stop"; color: Theme.textPrimary; font.pixelSize: 13 }
                            SpinBox {
                                id: stopSpin; from: 0; to: 1000000; value: 1000; stepSize: 100
                                editable: true; Layout.fillWidth: true
                                onValueChanged: page.recomputeSizes()
                            }
                            // Third parameter swaps with the profile: Step (linear) ↔ Points (geometric).
                            Label {
                                text: "Step"; color: Theme.textPrimary; font.pixelSize: 13
                                visible: profileBox.currentText !== "Large range"   // Small steps or Custom
                            }
                            SpinBox {
                                id: stepSpin; from: 0; to: 100000; value: 50; stepSize: 10
                                editable: true; Layout.fillWidth: true
                                visible: profileBox.currentText !== "Large range"   // Small steps or Custom
                                onValueChanged: page.recomputeSizes()
                            }
                            Label {
                                text: "Points"; color: Theme.textPrimary; font.pixelSize: 13
                                visible: profileBox.currentText === "Large range"
                            }
                            SpinBox {
                                id: pointsSpin; from: 2; to: 30; value: 7
                                editable: true; Layout.fillWidth: true
                                visible: profileBox.currentText === "Large range"
                                onValueChanged: page.recomputeSizes()
                            }
                        }

                        // Custom only: generate a Start/Step/Stop range into the editable
                        // list — Set replaces it, Add merges it (deduped + sorted) so several
                        // ranges can be composed.
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: profileBox.currentText === "Custom"
                            UiButton {
                                id: setBtn
                                text: "Set range"
                                Layout.fillWidth: true
                                onClicked: page.customSet()
                                ToolTip.visible: setBtn.hovered
                                ToolTip.text: "Replace the list with the Start → Stop by Step range above"
                            }
                            UiButton {
                                id: addBtn
                                text: "Add range"
                                Layout.fillWidth: true
                                onClicked: page.customAdd()
                                ToolTip.visible: addBtn.hovered
                                ToolTip.text: "Merge the Start → Stop by Step range into the current list (deduped, sorted)"
                            }
                        }

                        // The generated list (read-only), or the hand-edited list in Custom.
                        // Multi-line + wrapping so a long list (or pasted/loaded text) is
                        // readable; copy/paste works natively when editable (Custom).
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 72
                            clip: true
                            TextArea {
                                id: sizesField
                                text: "100, 150, 200, 250, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 800, 850, 900, 950, 1000"
                                readOnly: profileBox.currentText !== "Custom"
                                wrapMode: TextEdit.WrapAnywhere
                                selectByMouse: true
                                placeholderText: "e.g. 100, 200, 500, 1000  (commas, spaces or new lines)"
                                background: Rectangle {
                                    radius: 4
                                    color: sizesField.readOnly ? "transparent" : Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.04)
                                    border.color: sizesField.activeFocus ? Theme.accent : Theme.panelBorder
                                    border.width: 1
                                }
                            }
                        }

                        // Live validation + a Load button (Custom only).
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Label {
                                Layout.fillWidth: true
                                text: page.sizesHint(sizesField.text)
                                wrapMode: Text.WordWrap
                                font.pixelSize: 12
                                color: {
                                    var s = page.sizesStats(sizesField.text);
                                    return s.valid.length === 0 ? Theme.stSource
                                         : s.bad.length ? Theme.stCurrent
                                         : Theme.textMuted;
                                }
                            }
                            UiButton {
                                id: saveBtn
                                text: "Save"
                                visible: profileBox.currentText === "Custom"
                                enabled: page.sizesStats(sizesField.text).valid.length > 0
                                onClicked: sizesSaveDialog.open()
                                ToolTip.visible: saveBtn.hovered
                                ToolTip.text: "Save the current Sizes list to a text file"
                            }
                            UiButton {
                                id: loadBtn
                                text: "Load"
                                visible: profileBox.currentText === "Custom"
                                onClicked: sizesLoadDialog.open()
                                ToolTip.visible: loadBtn.hovered
                                ToolTip.text: "Load sizes from a text/CSV file (numbers separated by commas, spaces or new lines)"
                            }
                        }
                    }

                    // ---- Options (collapsible) ----
                    SectionHeader {
                        title: "Options"; expanded: page.secOptions
                        onToggled: page.secOptions = !page.secOptions
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 8; visible: page.secOptions

                        RowLayout {
                            Layout.fillWidth: true; spacing: 12
                            CheckBox { id: directedBox; text: "Directed" }
                            CheckBox { id: weightedBox; text: "Weighted"; checked: true }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 8
                            rowSpacing: 6

                            Label { text: "Avg degree"; color: Theme.textPrimary; font.pixelSize: 13 }
                            SpinBox {
                                id: degSpin; from: 1; to: 100; value: 6; editable: true; Layout.fillWidth: true
                                HoverHandler { id: degHover }
                                ToolTip.visible: degHover.hovered
                                ToolTip.delay: 400
                                ToolTip.text: "Target average vertex degree for random / scale-free graphs (edge density). Ignored by grid and complete, whose degree is fixed by their structure."
                            }

                            Label { text: "Repetitions"; color: Theme.textPrimary; font.pixelSize: 13 }
                            SpinBox {
                                id: repsSpin; from: 1; to: 50; value: 5; editable: true; Layout.fillWidth: true
                                HoverHandler { id: repsHover }
                                ToolTip.visible: repsHover.hovered
                                ToolTip.delay: 400
                                ToolTip.text: "Number of timed runs per cell; min / median / mean / σ are computed over these (plus one untimed warm-up)."
                            }

                            Label { text: "Seed"; color: Theme.textPrimary; font.pixelSize: 13 }
                            SpinBox {
                                id: seedSpin; from: 0; to: 1000000; value: 1; editable: true; Layout.fillWidth: true
                                HoverHandler { id: seedHover }
                                ToolTip.visible: seedHover.hovered
                                ToolTip.delay: 400
                                ToolTip.text: "RNG seed for graph generation. Fix it for reproducible graphs; change it to sample a different random instance of the same size."
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true; Layout.topMargin: 6; spacing: 8
                        UiButton {
                            text: "Run"
                            highlighted: true
                            // Disabled while running or when the sizes text has no valid value.
                            enabled: !analyzer.running && page.sizesStats(sizesField.text).valid.length > 0
                            Layout.fillWidth: true
                            onClicked: page.doRun()
                        }
                        UiButton {
                            text: "Cancel"
                            enabled: analyzer.running
                            Layout.fillWidth: true
                            onClicked: analyzer.cancel()
                        }
                    }

                    ProgressBar {
                        Layout.fillWidth: true
                        from: 0; to: 1
                        value: analyzer.progress
                        visible: analyzer.running || analyzer.progress > 0
                    }
                    Label {
                        Layout.fillWidth: true
                        text: analyzer.status
                        color: Theme.textMuted
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        visible: text.length > 0
                    }

                    RowLayout {
                        Layout.fillWidth: true; Layout.topMargin: 6; spacing: 8
                        UiButton {
                            text: "Clear"
                            enabled: analyzer.resultsModel.count > 0 && !analyzer.running
                            Layout.fillWidth: true
                            onClicked: analyzer.clearResults()
                        }
                        UiButton {
                            text: "Export CSV"
                            enabled: analyzer.resultsModel.count > 0
                            Layout.fillWidth: true
                            onClicked: csvDialog.open()
                        }
                    }
                }
            }

            // Pinned live-utilisation monitor (below the scroll area), collapsible.
            LiveUtilization {
                Layout.fillWidth: true
                active: page.visible
                expanded: page.secMonitor
                onToggled: page.secMonitor = !page.secMonitor
            }
            }
        }

        // ---- results table ----
        Frame {
            SplitView.fillWidth: true
            SplitView.minimumWidth: 320
            background: Rectangle { color: Theme.panelBg; border.color: Theme.panelBorder; radius: 8 }

            // Results table (top) and scaling chart (bottom) stacked in a vertical
            // SplitView so the user can drag the divider to trade height between
            // them — a big table when scanning many rows, a big chart when reading
            // the scaling curves. Mirrors the workspace splitter's handle style.
            SplitView {
                id: resultsSplit
                anchors.fill: parent
                orientation: Qt.Vertical

                // Restore the saved divider position on load, and write it back when
                // the page is torn down (app close / page switch), so heights persist.
                Component.onCompleted: if (settings.resultsSplitState) restoreState(settings.resultsSplitState)
                Component.onDestruction: settings.resultsSplitState = saveState()

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

                // ---- results table (top) ----
                Item {
                    SplitView.preferredHeight: 240
                    SplitView.minimumHeight: 96
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        // header row
                        Row {
                            Layout.fillWidth: true
                            spacing: 0
                            Repeater {
                                model: page.columns
                                delegate: Item {
                                    id: hcell
                                    required property var modelData
                                    required property int index
                                    width: page.colWidths[index]
                                    height: hlabel.implicitHeight
                                    // Explain the column on hover. HoverHandler is passive,
                                    // so it coexists with the resize MouseArea on the edge.
                                    HoverHandler { id: hcellHover }
                                    ToolTip.visible: hcellHover.hovered && !!hcell.modelData.tip
                                    ToolTip.text: hcell.modelData.tip || ""
                                    ToolTip.delay: 400
                                    Label {
                                        id: hlabel
                                        anchors.fill: parent
                                        text: hcell.modelData.title
                                        font.bold: true; font.pixelSize: 13
                                        color: Theme.textPrimary
                                        padding: 8
                                        elide: Text.ElideRight
                                    }
                                    // Vertical separator on the left edge marking a new
                                    // semantic group (loads / ops / time / resources).
                                    Rectangle {
                                        visible: hcell.modelData.groupStart === true
                                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                        width: 2
                                        color: Theme.panelBorder
                                    }
                                    // Drag the right edge to resize this column. Both the
                                    // header and the data rows read page.colWidths[index],
                                    // so they resize together and stay aligned.
                                    MouseArea {
                                        width: 8
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        cursorShape: Qt.SizeHorCursor
                                        preventStealing: true
                                        property real startX: 0
                                        property real startW: 0
                                        onPressed: function (m) {
                                            startW = page.colWidths[hcell.index];
                                            startX = mapToItem(null, m.x, m.y).x;
                                        }
                                        onPositionChanged: function (m) {
                                            if (!pressed) return;
                                            var gx = mapToItem(null, m.x, m.y).x;
                                            page.setColWidth(hcell.index, startW + (gx - startX));
                                        }
                                    }
                                }
                            }
                        }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.panelBorder }

                        // empty-state hint
                        Label {
                            visible: analyzer.resultsModel.count === 0
                            Layout.fillWidth: true; Layout.topMargin: 24
                            horizontalAlignment: Text.AlignHCenter
                            text: "No results yet — configure a benchmark and press Run."
                            color: Theme.textMuted; font.pixelSize: 13
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: analyzer.resultsModel
                            ScrollBar.vertical: ScrollBar {}
                            // Incremental model (AnalyzerResultsModel): each delegate reads
                            // the row map (rowData) and the precomputed size-group flag
                            // (groupStart) as roles — appends don't rebuild the whole table.
                            delegate: Item {
                                id: rowItem
                                required property var rowData
                                required property bool groupStart
                                required property int index
                                width: ListView.view.width
                                height: 30 + (groupStart ? 2 : 0)

                                // Divider before the first row of each new N block.
                                Rectangle {
                                    anchors.top: parent.top
                                    width: parent.width; height: 2
                                    visible: rowItem.groupStart
                                    color: Theme.panelBorder
                                }
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width; height: 30
                                    // Flag swap-distorted rows with a red wash; otherwise
                                    // the usual zebra striping.
                                    color: rowItem.rowData.swapRisk
                                           ? Qt.rgba(Theme.stSource.r, Theme.stSource.g, Theme.stSource.b, 0.15)
                                           : (rowItem.index % 2 === 0) ? "transparent"
                                                                       : Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.04)
                                    Row {
                                        anchors.fill: parent
                                        spacing: 0
                                        Repeater {
                                            model: page.columns
                                            delegate: Label {
                                                id: cell
                                                required property var modelData
                                                required property int index
                                                width: page.colWidths[cell.index]
                                                text: page.fmt(rowItem.rowData, cell.modelData)
                                                // Colour the row with its algorithm's series
                                                // colour so the table reads against the chart's
                                                // legend at a glance (same mapping as the chart).
                                                color: scalingChart.seriesColor(rowItem.rowData.algorithm)
                                                font.pixelSize: 12
                                                padding: 8
                                                elide: Text.ElideRight
                                                // Semantic-group separator (matches the header).
                                                Rectangle {
                                                    visible: cell.modelData.groupStart === true
                                                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                                    width: 2
                                                    color: Theme.panelBorder
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ---- scaling chart (bottom): time / peak memory vs N ----
                Item {
                    SplitView.fillHeight: true
                    SplitView.minimumHeight: 140
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.bottomMargin: 6
                            spacing: 8
                            Label { text: "Scaling vs N"; font.bold: true; font.pixelSize: 14; color: Theme.textPrimary }
                            Item { Layout.fillWidth: true }
                            Label { text: "Metric:"; color: Theme.textMuted; font.pixelSize: 12 }
                            UiButton {
                                text: "Time"; checkable: true; checked: scalingChart.metric === "time"
                                onClicked: scalingChart.metric = "time"
                            }
                            UiButton {
                                text: "Memory"; checkable: true; checked: scalingChart.metric === "mem"
                                onClicked: scalingChart.metric = "mem"
                            }
                        }
                        ScalingChart {
                            id: scalingChart
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 100
                            results: analyzer.results
                            algoOrder: analyzer.algorithms
                        }
                    }
                }
            }
        }
    }

    FileDialog {
        id: csvDialog
        title: "Export benchmark results"
        fileMode: FileDialog.SaveFile
        nameFilters: ["CSV (*.csv)", "All files (*)"]
        defaultSuffix: "csv"
        onAccepted: analyzer.exportCsv(selectedFile)
    }

    // Load a Custom sizes list from a text/CSV file (read in QML via XMLHttpRequest,
    // no C++ needed). Whatever separators the file uses, sizesStats() tolerates them.
    FileDialog {
        id: sizesLoadDialog
        title: "Load sizes from a text file"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Text / CSV (*.txt *.csv)", "All files (*)"]
        onAccepted: {
            var xhr = new XMLHttpRequest();
            xhr.open("GET", selectedFile);
            xhr.onreadystatechange = function () {
                if (xhr.readyState === XMLHttpRequest.DONE && (xhr.status === 200 || xhr.status === 0))
                    sizesField.text = xhr.responseText;
            };
            xhr.send();
        }
    }

    // Save the current sizes list to a text file (written by AnalyzerController).
    FileDialog {
        id: sizesSaveDialog
        title: "Save sizes to a text file"
        fileMode: FileDialog.SaveFile
        nameFilters: ["Text (*.txt)", "CSV (*.csv)", "All files (*)"]
        defaultSuffix: "txt"
        onAccepted: analyzer.saveTextFile(selectedFile, sizesField.text)
    }
}
