pragma ComponentBehavior: Bound
import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Window
import SortStudio
import UiKit

ApplicationWindow {
    id: win
    visible: true
    x: 120; y: 80; width: 1680; height: 900
    minimumWidth: 900
    minimumHeight: 560
    title: "Sort Algorithm Studio"
    color: Theme.windowBg
    flags: Qt.Window | Qt.FramelessWindowHint

    // Which workspace is on screen.
    property string page: "home"
    function goHome()        { win.stopPlay(); win.page = "home"; }
    function showVisualizer(){ win.page = "visualizer"; }
    function showAnalyzer()  { win.stopPlay(); win.page = "analyzer"; }
    function showKnowledge()  { win.stopPlay(); win.page = "knowledge"; }
    function showStability()  { win.stopPlay(); win.page = "stability"; }
    function showRace()       { win.stopPlay(); win.page = "race"; }

    // Theme + visualizer view state.
    property string themeName: "dark"
    property string viewMode: "bars"          // bars | dots | strip
    property bool showValues: false
    property bool showPseudocode: true          // Visualizer pseudocode panel visible
    property bool soundOn: false                 // play tones on each sort step
    property bool monitorExpanded: true        // Live-utilization panel expanded (both pages)
    property bool _maxed: false

    // Playback clock. Speed (steps/sec) is the source of truth; the run bar reads it.
    property real playSpeed: 6
    function stopPlay() { player.running = false; }

    Settings {
        property alias winX: win.x
        property alias winY: win.y
        property alias winWidth: win.width
        property alias winHeight: win.height
        property alias themeName: win.themeName
        property alias viewMode: win.viewMode
        property alias showValues: win.showValues
        property alias showPseudocode: win.showPseudocode
        property alias soundOn: win.soundOn
        property alias playSpeed: win.playSpeed
        property alias monitorExpanded: win.monitorExpanded
    }

    // Drive the shared palette from the selected theme.
    Binding { target: UiPalette; property: "themeName"; value: win.themeName }

    // Drive the Controls palette from the theme.
    palette.window: Theme.windowBg
    palette.windowText: Theme.textPrimary
    palette.base: Theme.panelBg
    palette.text: Theme.textPrimary
    palette.button: Theme.button
    palette.buttonText: Theme.textPrimary
    palette.highlight: Theme.accent
    palette.highlightedText: "#ffffff"
    palette.mid: Theme.panelBorder

    VisualizerController { id: ctl }
    AnalyzerController { id: analyzer }

    Timer {
        id: player
        interval: Math.round(1000 / win.playSpeed)
        repeat: true
        onTriggered: {
            ctl.stepForward();
            if (ctl.atEnd) running = false;
        }
    }

    function toggleMaximize() { if (_maxed) { showNormal(); _maxed = false; } else { showMaximized(); _maxed = true; } }

    header: TitleBar {
        title: win.page === "analyzer" ? "Sort Algorithm Analyzer"
             : win.page === "visualizer" ? "Sort Algorithm Visualizer"
             : win.page === "knowledge" ? "Sort Knowledge Base"
             : win.page === "stability" ? "Sort Stability"
             : win.page === "race" ? "Sort Race"
             : "Sort Algorithm Studio"
        version: Qt.application.version
        page: win.page
        themeName: win.themeName
        themeNames: UiPalette.themeNames
        maximized: win._maxed
        onMoveRequested: win.startSystemMove()
        onMaximizeToggled: win.toggleMaximize()
        onMinimizeRequested: win.showMinimized()
        onCloseRequested: win.close()
        onHomeRequested: win.goHome()
        onThemeSelected: (name) => win.themeName = name
    }

    // Frameless resize handles (thin strips on the edges).
    Item {
        anchors.fill: parent; z: 100
        MouseArea { width: 6; anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
                    cursorShape: Qt.SizeHorCursor; onPressed: win.startSystemResize(Qt.LeftEdge) }
        MouseArea { width: 6; anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                    cursorShape: Qt.SizeHorCursor; onPressed: win.startSystemResize(Qt.RightEdge) }
        MouseArea { height: 6; anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    cursorShape: Qt.SizeVerCursor; onPressed: win.startSystemResize(Qt.BottomEdge) }
        MouseArea { width: 12; height: 12; anchors { right: parent.right; bottom: parent.bottom }
                    cursorShape: Qt.SizeFDiagCursor; onPressed: win.startSystemResize(Qt.RightEdge | Qt.BottomEdge) }
    }

    // ---- workspaces ----
    HomePage {
        anchors.fill: parent; anchors.margins: 12
        visible: win.page === "home"
        onAnalyzerRequested: win.showAnalyzer()
        onVisualizerRequested: win.showVisualizer()
        onKnowledgeRequested: win.showKnowledge()
        onStabilityRequested: win.showStability()
        onRaceRequested: win.showRace()
    }

    VisualizerPage {
        anchors.fill: parent; anchors.margins: 12
        visible: win.page === "visualizer"
        win: win; ctl: ctl; player: player
    }

    AnalyzerPage {
        id: analyzerPage
        anchors.fill: parent; anchors.margins: 12
        visible: win.page === "analyzer"
        ctl: analyzer
        win: win
    }

    KnowledgePage {
        anchors.fill: parent; anchors.margins: 12
        visible: win.page === "knowledge"
        onVisualizeRequested: (algo) => { win.stopPlay(); ctl.algorithm = algo; win.showVisualizer(); }
        onBenchmarkRequested: (algo) => { analyzerPage.selectAlgo(algo); win.showAnalyzer(); }
    }

    StabilityPage {
        anchors.fill: parent; anchors.margins: 12
        visible: win.page === "stability"
    }

    RacePage {
        anchors.fill: parent; anchors.margins: 12
        visible: win.page === "race"
    }
}
