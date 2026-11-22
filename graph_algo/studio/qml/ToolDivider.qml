pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import GraphVis
import UiKit

// Styled vertical divider for toolbars/panes (a thin grey bar). Named ToolDivider
// — NOT "ToolSeparator" — so it doesn't shadow the built-in QtQuick.Controls type.
ToolSeparator {
    id: divider
    contentItem: Rectangle {
        anchors.centerIn: parent
        anchors.verticalCenter: parent.verticalCenter
        implicitHeight: 20
        implicitWidth: 4
        anchors.topMargin: 18
        color: "#99888888"
    }
}
