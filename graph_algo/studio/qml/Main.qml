pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Window
import GraphVis
import UiKit

// Standalone window chrome for Graph Algorithm Studio: a frameless ApplicationWindow
// that owns the title bar, theme and saved geometry, and hosts the studio content
// (GraphRoot). The same GraphRoot is embedded by the Algorithms umbrella, which
// supplies its own window and title bar — so all studio behaviour lives in GraphRoot
// and only the window shell (geometry, theme, full-screen, close-guard) is here.
ApplicationWindow {
    id: win
    visible: true
    x: 120; y: 80; width: 1680; height: 900
    // Minimum size (VS-style): the title bar's middle region (version + pickers)
    // collapses/clips as the window narrows, so we only need room for the app title
    // + the window min/max/close buttons (plus the body's panel+canvas minimums).
    minimumWidth: 720
    minimumHeight: 540
    title: "Graph Algorithm Studio"
    color: Theme.windowBg
    flags: Qt.Window | Qt.FramelessWindowHint

    // Selected UI theme (see UiPalette.themeNames). Empty until migrated from the
    // legacy darkMode bool in Component.onCompleted, then persisted on its own.
    property string themeName: ""
    property bool darkMode: true         // legacy — kept only to migrate old settings
    property bool _maxed: false
    function toggleMaximize() { if (_maxed) { showNormal(); _maxed = false; } else { showMaximized(); _maxed = true; } }

    Settings {
        property alias winX: win.x
        property alias winY: win.y
        property alias winWidth: win.width
        property alias winHeight: win.height
        property alias darkMode: win.darkMode     // legacy (migrated to themeName)
        property alias themeName: win.themeName
    }
    // The selected theme flows into the shared palette; the app's Theme delegates to it.
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

    // If the restored window geometry (winX/winY, persisted above) lands off every
    // currently-connected monitor — common after unplugging a monitor the app was
    // last shown on — the frameless window becomes unreachable: it's running (in the
    // taskbar) but visible on no screen, and there's no title bar to drag it back.
    // Pull it back onto a real screen. Runs at startup, after Settings has restored.
    function ensureOnScreen() {
        var screens = Application.screens;
        if (!screens || screens.length === 0)
            return;
        var need = 120;                       // px of the window that must stay visible
        var wr = win.x + win.width, wb = win.y + win.height;
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i];
            var ix = Math.max(win.x, s.virtualX);
            var iy = Math.max(win.y, s.virtualY);
            var ixr = Math.min(wr, s.virtualX + s.width);
            var iyb = Math.min(wb, s.virtualY + s.height);
            if (ixr - ix >= need && iyb - iy >= need)
                return;                       // enough of it shows on this screen — keep it
        }
        // Off every screen: clamp the size to the primary screen and recentre there.
        var p = screens[0];
        win.width = Math.min(win.width, p.width - 80);
        win.height = Math.min(win.height, p.height - 80);
        win.x = p.virtualX + Math.round((p.width - win.width) / 2);
        win.y = p.virtualY + Math.round((p.height - win.height) / 2);
    }

    Component.onCompleted: {
        ensureOnScreen();                     // rescue an off-screen restored position
        // One-time migration: existing installs persisted only the darkMode bool.
        if (!win.themeName) win.themeName = win.darkMode ? "dark" : "light";
    }

    // Full-screen canvas is owned by the content (GraphRoot.canvasFull); the window
    // reflects it into its visibility. Imperative (not a binding) so it doesn't fight
    // the showMaximized()/showNormal() calls in toggleMaximize().
    Connections {
        target: root
        function onCanvasFullChanged() {
            win.visibility = root.canvasFull ? Window.FullScreen : Window.Windowed;
        }
    }

    // Close-confirmation: veto the first close when the document is modified, ask via
    // the content's guard, then close. Autosave the session on every close.
    property bool _forceClose: false
    onClosing: function (close) {
        if (root._ready) root.autosaveSession();   // remember the last document for next launch
        if (root.modified && !win._forceClose) {
            close.accepted = false;
            root.confirmUnsaved(function () { win._forceClose = true; win.close(); });
        }
    }

    header: TitleBar {
        // The title names the current workspace (just the Studio on the home page).
        title: root.pageTitle
        version: Qt.application.version
        page: root.page
        themeName: win.themeName
        themeNames: UiPalette.themeNames
        accentColor: UiPalette.accent          // effective accent (override or preset)
        accentIsCustom: root.userAccent.a > 0
        maximized: win._maxed
        win: root; ctl: root.visCtl; graph: root.view2d; graph3d: root.view3d; dialogs: root.dlgs
        onMoveRequested: win.startSystemMove()
        onMaximizeToggled: win.toggleMaximize()
        onMinimizeRequested: win.showMinimized()
        onCloseRequested: win.close()
        onHomeRequested: root.goHome()
        onThemeSelected: (name) => win.themeName = name
        onAccentPickRequested: root.dlgs.openAccent(UiPalette.accent)
        onAccentResetRequested: root.userAccent = "transparent"
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

    GraphRoot {
        id: root
        anchors.fill: parent
        anchors.margins: 12
    }
}
