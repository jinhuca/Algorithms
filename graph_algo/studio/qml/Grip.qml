import QtQuick
import GraphVis

// Shared drag grip for the draggable on-canvas panes (2D + 3D). `host` is the
// view the pane lives in (used for coordinate mapping and clamping) and `pane`
// is the rectangle being moved; the clamped new top-left is emitted via
// movedTo. preventStealing keeps the drag from leaking into the canvas/orbit
// controllers underneath.
MouseArea {
    id: grip
    property Item host
    property Item pane
    signal movedTo(real nx, real ny)
    width: 16; height: 28
    cursorShape: Qt.SizeAllCursor
    preventStealing: true
    property real ox: 0; property real oy: 0
    onPressed: function (m) { var g = mapToItem(host, m.x, m.y); ox = g.x - pane.x; oy = g.y - pane.y; }
    onPositionChanged: function (m) {
        if (!pressed) return;
        var g = mapToItem(host, m.x, m.y);
        movedTo(Math.max(0, Math.min(host.width - pane.width, g.x - ox)),
                Math.max(0, Math.min(host.height - pane.height, g.y - oy)));
    }
    Text { anchors.centerIn: parent; text: "⠿"; color: Theme.textMuted; font.pixelSize: 14 }
}
