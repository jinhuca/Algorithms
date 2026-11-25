pragma ComponentBehavior: Bound
import QtCore
import QtQuick
import SortStudio
import UiKit

// Sort Algorithm Studio content, with no window chrome — the page bodies, their
// navigation + view state, the controllers and the playback clock. Hosted two ways:
//   * standalone, inside this studio's thin Main.qml (frameless ApplicationWindow);
//   * embedded in the Algorithms umbrella, swapped in by a Loader.
// The host owns the window, title bar and theme; this root exposes `page`,
// `pageTitle` and `goHome()` for the host's title bar to read/drive.
Item {
    id: root

    // Controls this studio contributes to the umbrella title bar (none — Sort's
    // workspace controls live on its pages).
    property Component titleControls: null

    // Identity shown in the host (umbrella) title bar when this studio is active.
    // `version` is build-stamped (Major.Minor.Patch.Build from version.h via the controller).
    readonly property string iconSource: "qrc:/qt/qml/SortStudio/sa_logo.png"
    readonly property string version: ctl.appVersion   // build-stamped, from version.h

    // Which workspace is on screen.
    property string page: "home"
    function goHome()         { root.stopPlay(); root.page = "home"; }
    function showVisualizer() { root.page = "visualizer"; }
    function showAnalyzer()   { root.stopPlay(); root.page = "analyzer"; }
    function showKnowledge()  { root.stopPlay(); root.page = "knowledge"; }
    function showStability()  { root.stopPlay(); root.page = "stability"; }
    function showRace()       { root.stopPlay(); root.page = "race"; }

    // Title the host window shows for the current page.
    readonly property string pageTitle:
          page === "analyzer"   ? "Sort Algorithm Analyzer"
        : page === "visualizer" ? "Sort Algorithm Visualizer"
        : page === "knowledge"  ? "Sort Knowledge Base"
        : page === "stability"  ? "Sort Stability"
        : page === "race"       ? "Sort Race"
        :                         "Sort Algorithm Studio"

    // Visualizer view state (persisted under the "sort" settings category so it never
    // collides with another studio's state when both run in the umbrella process).
    property string viewMode: "bars"          // bars | dots | strip
    property bool showValues: false
    property bool showPseudocode: true          // Visualizer pseudocode panel visible
    property bool soundOn: false                 // play tones on each sort step
    property bool monitorExpanded: true        // Live-utilization panel expanded (both pages)

    // Playback clock. Speed (steps/sec) is the source of truth; the run bar reads it.
    property real playSpeed: 6
    function stopPlay() { player.running = false; }

    Settings {
        category: "sort"
        property alias viewMode: root.viewMode
        property alias showValues: root.showValues
        property alias showPseudocode: root.showPseudocode
        property alias soundOn: root.soundOn
        property alias playSpeed: root.playSpeed
        property alias monitorExpanded: root.monitorExpanded
    }

    VisualizerController { id: ctl }
    AnalyzerController { id: analyzer }

    Timer {
        id: player
        interval: Math.round(1000 / root.playSpeed)
        repeat: true
        onTriggered: {
            ctl.stepForward();
            if (ctl.atEnd) running = false;
        }
    }

    // ---- workspaces ----
    HomePage {
        anchors.fill: parent
        visible: root.page === "home"
        onAnalyzerRequested: root.showAnalyzer()
        onVisualizerRequested: root.showVisualizer()
        onKnowledgeRequested: root.showKnowledge()
        onStabilityRequested: root.showStability()
        onRaceRequested: root.showRace()
    }

    VisualizerPage {
        anchors.fill: parent
        visible: root.page === "visualizer"
        win: root; ctl: ctl; player: player
    }

    AnalyzerPage {
        id: analyzerPage
        anchors.fill: parent
        visible: root.page === "analyzer"
        ctl: analyzer
        win: root
    }

    KnowledgePage {
        anchors.fill: parent
        visible: root.page === "knowledge"
        onVisualizeRequested: (algo) => { root.stopPlay(); ctl.algorithm = algo; root.showVisualizer(); }
        onBenchmarkRequested: (algo) => { analyzerPage.selectAlgo(algo); root.showAnalyzer(); }
    }

    StabilityPage {
        anchors.fill: parent
        visible: root.page === "stability"
    }

    RacePage {
        anchors.fill: parent
        visible: root.page === "race"
    }
}
