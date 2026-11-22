pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import SearchStudio

// The animated bar chart for a search: one bar per array element, height ∝ value,
// coloured by playback state (idle / in-window / probe / eliminated / found). Binds to
// the controller's BarModel so only the changed bars repaint each step. The values are
// fixed (a search only reads) — only the colours move.
Item {
    id: view
    property var model
    property real maxValue: 1
    property bool showValues: false

    readonly property int cnt: model ? model.count : 0
    readonly property real gap: cnt > 120 ? 1 : (cnt > 48 ? 2 : 4)
    readonly property real barW: cnt > 0 ? Math.max(1, (width - gap * (cnt - 1)) / cnt) : 0

    Repeater {
        model: view.model
        delegate: Rectangle {
            id: bar
            required property int index
            required property real value
            required property int barState

            width: view.barW
            x: index * (view.barW + view.gap)
            height: Math.max(2, (view.maxValue > 0 ? value / view.maxValue : 0)
                                * (view.height - (view.showValues ? 16 : 0)))
            y: view.height - height
            radius: view.barW > 6 ? 2 : 0
            color: Theme.barColor(barState)
            antialiasing: true

            Behavior on color { ColorAnimation { duration: 90 } }

            Label {
                visible: view.showValues && view.barW >= 14
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                text: Math.round(bar.value)
                color: Theme.textMuted
                font.pixelSize: 9
            }
        }
    }
}
