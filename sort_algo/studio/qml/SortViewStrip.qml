pragma ComponentBehavior: Bound
import QtQuick
import SortStudio

// Colour-strip view: each element is a full-height vertical band whose HUE encodes
// its value (rainbow from value 0 → max). Sorting turns visual noise into a smooth
// spectrum sweep. Playback-state elements are tinted toward their state colour so
// the active compares/swaps still stand out against the spectrum.
Item {
    id: view
    property var model
    property real maxValue: 1

    readonly property int cnt: model ? model.count : 0
    readonly property real bandW: cnt > 0 ? width / cnt : 0

    Repeater {
        model: view.model
        delegate: Rectangle {
            required property int index
            required property real value
            required property int barState

            x: index * view.bandW
            width: Math.ceil(view.bandW) + 1    // +1 avoids sub-pixel seams
            height: view.height
            // Hue 0 (red) .. 0.83 (violet) across the value range.
            readonly property real hue: view.maxValue > 0
                ? 0.83 * (1 - value / view.maxValue) : 0
            readonly property color spectrum: Qt.hsva(hue, 0.75, 0.95, 1)
            color: barState === 0 || barState === 4
                   ? spectrum
                   : Qt.tint(spectrum, Qt.rgba(Theme.barColor(barState).r,
                                               Theme.barColor(barState).g,
                                               Theme.barColor(barState).b, 0.65))
            Behavior on color { ColorAnimation { duration: 90 } }
        }
    }
}
