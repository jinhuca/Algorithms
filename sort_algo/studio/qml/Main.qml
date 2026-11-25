pragma ComponentBehavior: Bound
import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Window
import SortStudio
import UiKit

// Standalone window chrome for Sort Algorithm Studio: a frameless ApplicationWindow
// that owns the title bar, theme and saved geometry, and hosts the studio content
// (SortRoot). The same SortRoot is embedded by the Algorithms umbrella, which supplies
// its own window and title bar — so all studio behaviour lives in SortRoot and only
// the window shell is duplicated here.
ApplicationWindow {
    id: win
    visible: true
    x: 120; y: 80; width: 1680; height: 900
    minimumWidth: 900
    minimumHeight: 560
    title: "Sort Algorithm Studio"
    color: Theme.windowBg
    flags: Qt.Window | Qt.FramelessWindowHint

    property string themeName: "dark"
    property bool _maxed: false

    Settings {
        property alias winX: win.x
        property alias winY: win.y
        property alias winWidth: win.width
        property alias winHeight: win.height
        property alias themeName: win.themeName
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

    function toggleMaximize() { if (_maxed) { showNormal(); _maxed = false; } else { showMaximized(); _maxed = true; } }

    // If the restored window geometry (winX/winY, persisted above) lands off every
    // currently-connected monitor — common after unplugging/replugging monitors or
    // moving the install to a machine with a different display layout — the frameless
    // window becomes unreachable: it's running (in the taskbar) but visible on no
    // screen, and there's no title bar to drag it back. Pull it back onto a real
    // screen. Runs at startup, after Settings has restored the saved geometry.
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

    Component.onCompleted: ensureOnScreen()   // rescue an off-screen restored position

    header: TitleBar {
        title: root.pageTitle
        version: Qt.application.version
        page: root.page
        themeName: win.themeName
        themeNames: UiPalette.themeNames
        maximized: win._maxed
        onMoveRequested: win.startSystemMove()
        onMaximizeToggled: win.toggleMaximize()
        onMinimizeRequested: win.showMinimized()
        onCloseRequested: win.close()
        onHomeRequested: root.goHome()
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

    SortRoot {
        id: root
        anchors.fill: parent
        anchors.margins: 12
    }
}
