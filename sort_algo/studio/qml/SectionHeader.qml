pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SortStudio

// A clickable control-panel section caption with a collapse/expand chevron. The
// section body is a sibling shown/hidden on the caller's `expanded` flag; clicking
// the row emits toggled().
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
        text: (h.expanded ? "▾  " : "▸  ") + h.title
        font.bold: true; font.pixelSize: 13; color: Theme.textPrimary
    }
    TapHandler { onTapped: h.toggled() }
}
