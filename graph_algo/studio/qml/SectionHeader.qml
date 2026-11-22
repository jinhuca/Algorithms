pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import GraphVis

// A clickable control-panel section caption with a collapse/expand chevron.
// The section body is a sibling in Main.qml, shown/hidden on the caller's
// `expanded` flag; clicking anywhere on the row emits toggled(). Header-only by
// design (a reusable content slot fights QML's default-property rules when the
// root is a Layout), so Main.qml wraps each section's body itself.
RowLayout {
    id: h
    property string title: ""
    property bool expanded: true
    signal toggled()

    Layout.fillWidth: true
    Layout.topMargin: 2
    spacing: 6

    Label {
        Layout.fillWidth: true
        text: (h.expanded ? "▾  " : "▸  ") + h.title   // ▾ / ▸
        font.bold: true; font.pixelSize: 15; color: Theme.textPrimary
    }
    TapHandler { onTapped: h.toggled() }
}
