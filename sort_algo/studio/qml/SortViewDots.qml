pragma ComponentBehavior: Bound
import QtQuick
import SortStudio

// Scatter / dot view: each element is a dot at x = index, y ∝ value. A sorted array
// forms a clean diagonal line, so the approach to "sorted" reads at a glance. Same
// per-element state colouring as the bar view.
Item {
    id: view
    property var model
    property real maxValue: 1

    readonly property int cnt: model ? model.count : 0
    readonly property real step: cnt > 0 ? width / cnt : 0
    readonly property real dotSize: Math.max(2, Math.min(10, step * 0.8))

    Repeater {
        model: view.model
        delegate: Rectangle {
            required property int index
            required property real value
            required property int barState

            width: view.dotSize; height: view.dotSize
            radius: width / 2
            x: index * view.step + (view.step - width) / 2
            y: view.height - width
                - (view.maxValue > 0 ? value / view.maxValue : 0) * (view.height - width)
            color: Theme.barColor(barState)
            antialiasing: true
            Behavior on y { enabled: view.cnt <= 120; NumberAnimation { duration: 90 } }
            Behavior on color { ColorAnimation { duration: 90 } }
        }
    }
}
