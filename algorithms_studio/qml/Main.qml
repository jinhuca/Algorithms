pragma ComponentBehavior: Bound
import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Window
import Algorithms
import UiKit

// Algorithms umbrella window: one frameless ApplicationWindow that owns the title
// bar, theme and saved geometry, and hosts every studio's content in the same window.
// The home page's cards pick a studio; each studio's chrome-free Root (SortRoot /
// SearchRoot / GraphRoot) is loaded lazily by qrc URL and kept alive once visited, so
// switching studios doesn't lose their state. Loading by URL (not by importing the
// three studio modules here) keeps each module's `Theme` singleton unambiguous.
ApplicationWindow {
    id: win
    visible: true
    x: 120; y: 80; width: 1680; height: 900
    minimumWidth: 900
    minimumHeight: 560
    title: win.currentTitle
    color: UiPalette.windowBg
    flags: Qt.Window | Qt.FramelessWindowHint

    // Which studio (or the landing page) is on screen.
    property string activeStudio: "home"   // home | search | sort | graph | foundation | combinatorics | numerics
    property string themeName: "dark"
    // App-wide accent override (transparent = use the theme's preset accent). Owned
    // here so the accent swatch is a single, consistent control for every studio.
    property color userAccent: "transparent"
    property bool _maxed: false

    function show(id) {
        win.activeStudio = id;
        if (id === "search") searchLoader.keep = true;
        else if (id === "sort") sortLoader.keep = true;
        else if (id === "tree") treeLoader.keep = true;
        else if (id === "graph") graphLoader.keep = true;
        else if (id === "foundation") foundationLoader.keep = true;
        else if (id === "combinatorics") combinatoricsLoader.keep = true;
        else if (id === "numerics") numericsLoader.keep = true;
    }
    function goHome() { win.activeStudio = "home"; }

    // Is the active studio showing a workspace (one level above its own landing)?
    // Real studios expose a `page` string ("home" = their landing); skeletons don't.
    readonly property bool inWorkspace: {
        var r = win.activeRoot;
        return !!r && r.page !== undefined && r.page !== "home";
    }
    // Up one level: workspace -> that studio's landing; otherwise -> Algorithms home.
    function goUp() {
        if (win.inWorkspace) win.activeRoot.goHome();   // back to the studio's workspace picker
        else win.goHome();                              // back to the Algorithms home
    }

    // The currently-visible studio Root (null on the home / coming-soon pages). Its
    // `pageTitle` drives the title bar and its `titleControls` fills the controls slot.
    readonly property var activeRoot:
          win.activeStudio === "search"        ? searchLoader.item
        : win.activeStudio === "sort"          ? sortLoader.item
        : win.activeStudio === "tree"          ? treeLoader.item
        : win.activeStudio === "graph"         ? graphLoader.item
        : win.activeStudio === "foundation"    ? foundationLoader.item
        : win.activeStudio === "combinatorics" ? combinatoricsLoader.item
        : win.activeStudio === "numerics"      ? numericsLoader.item
        :                                        null
    readonly property string currentTitle: (activeRoot && activeRoot.pageTitle) ? activeRoot.pageTitle : "Algorithms"

    Settings {
        property alias winX: win.x
        property alias winY: win.y
        property alias winWidth: win.width
        property alias winHeight: win.height
        property alias themeName: win.themeName
        property alias userAccent: win.userAccent
    }

    // The single source of the theme for the whole process — every studio's Theme
    // delegates to this shared palette, so changing it here retints all of them.
    Binding { target: UiPalette; property: "themeName"; value: win.themeName }
    // App-wide accent override. GraphRoot's own accent binding is gated off while
    // embedded (see GraphRoot.embedded), so this is the only driver in the umbrella.
    Binding { target: UiPalette; property: "accentOverride"; value: win.userAccent }

    // Shared colour picker for the accent swatch.
    ColorDialog {
        id: accentDialog
        title: "Choose accent colour"
        onAccepted: win.userAccent = selectedColor
    }

    palette.window: UiPalette.windowBg
    palette.windowText: UiPalette.textPrimary
    palette.base: UiPalette.panelBg
    palette.text: UiPalette.textPrimary
    palette.button: UiPalette.button
    palette.buttonText: UiPalette.textPrimary
    palette.highlight: UiPalette.accent
    palette.highlightedText: "#ffffff"
    palette.mid: UiPalette.panelBorder

    function toggleMaximize() { if (_maxed) { showNormal(); _maxed = false; } else { showMaximized(); _maxed = true; } }

    // Rescue an off-screen restored position (see the studios' identical helper).
    function ensureOnScreen() {
        var screens = Application.screens;
        if (!screens || screens.length === 0)
            return;
        var need = 120;
        var wr = win.x + win.width, wb = win.y + win.height;
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i];
            var ix = Math.max(win.x, s.virtualX);
            var iy = Math.max(win.y, s.virtualY);
            var ixr = Math.min(wr, s.virtualX + s.width);
            var iyb = Math.min(wb, s.virtualY + s.height);
            if (ixr - ix >= need && iyb - iy >= need)
                return;
        }
        var p = screens[0];
        win.width = Math.min(win.width, p.width - 80);
        win.height = Math.min(win.height, p.height - 80);
        win.x = p.virtualX + Math.round((p.width - win.width) / 2);
        win.y = p.virtualY + Math.round((p.height - win.height) / 2);
    }

    Component.onCompleted: ensureOnScreen()

    header: TitleBar {
        title: win.currentTitle
        // Show the active studio's icon + version; fall back to the app's on the home page.
        iconSource: (win.activeRoot && win.activeRoot.iconSource)
                    ? win.activeRoot.iconSource : "qrc:/qt/qml/Algorithms/Algorithm_Icon.svg"
        version: (win.activeRoot && win.activeRoot.version)
                 ? win.activeRoot.version : Qt.application.version
        atHome: win.activeStudio === "home"
        canUp: win.inWorkspace
        themeName: win.themeName
        themeNames: UiPalette.themeNames
        maximized: win._maxed
        studioControls: win.activeRoot ? win.activeRoot.titleControls : null
        onMoveRequested: win.startSystemMove()
        onMaximizeToggled: win.toggleMaximize()
        onMinimizeRequested: win.showMinimized()
        onCloseRequested: win.close()
        onHomeRequested: win.goHome()
        onUpRequested: win.goUp()
        onThemeSelected: (name) => win.themeName = name
        accentColor: UiPalette.accent
        accentIsCustom: win.userAccent.a > 0
        onAccentPickRequested: { accentDialog.selectedColor = UiPalette.accent; accentDialog.open(); }
        onAccentResetRequested: win.userAccent = "transparent"
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

    // ---- home ----
    HomePage {
        anchors.fill: parent; anchors.margins: 12
        visible: win.activeStudio === "home"
        onStudioRequested: (id) => win.show(id)
    }

    // ---- studios (lazy, kept alive once visited) ----
    Loader {
        id: searchLoader
        anchors.fill: parent; anchors.margins: 12
        property bool keep: false
        active: keep
        visible: win.activeStudio === "search"
        source: "qrc:/qt/qml/SearchStudio/qml/SearchRoot.qml"
    }
    Loader {
        id: sortLoader
        anchors.fill: parent; anchors.margins: 12
        property bool keep: false
        active: keep
        visible: win.activeStudio === "sort"
        source: "qrc:/qt/qml/SortStudio/qml/SortRoot.qml"
    }
    Loader {
        id: treeLoader
        anchors.fill: parent; anchors.margins: 12
        property bool keep: false
        active: keep
        visible: win.activeStudio === "tree"
        source: "qrc:/qt/qml/TreeStudio/qml/TreeRoot.qml"
    }
    Loader {
        id: graphLoader
        anchors.fill: parent; anchors.margins: 12
        property bool keep: false
        active: keep
        visible: win.activeStudio === "graph"
        source: "qrc:/qt/qml/GraphVis/qml/GraphRoot.qml"
        // The umbrella owns the app-wide accent; tell GraphRoot not to drive it.
        onLoaded: if (item) item.embedded = true
    }
    Loader {
        id: foundationLoader
        anchors.fill: parent; anchors.margins: 12
        property bool keep: false
        active: keep
        visible: win.activeStudio === "foundation"
        source: "qrc:/qt/qml/FoundationStudio/qml/FoundationRoot.qml"
    }
    Loader {
        id: combinatoricsLoader
        anchors.fill: parent; anchors.margins: 12
        property bool keep: false
        active: keep
        visible: win.activeStudio === "combinatorics"
        source: "qrc:/qt/qml/CombinatoricsStudio/qml/CombinatoricsRoot.qml"
    }
    Loader {
        id: numericsLoader
        anchors.fill: parent; anchors.margins: 12
        property bool keep: false
        active: keep
        visible: win.activeStudio === "numerics"
        source: "qrc:/qt/qml/NumericsStudio/qml/NumericsRoot.qml"
    }
}
