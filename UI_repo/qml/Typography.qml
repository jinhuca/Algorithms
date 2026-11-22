pragma Singleton
import QtQuick

// Shared typography tokens — font families + a small size scale. Replace with
// Figma-exported type tokens. (Sizes are the ones graph_algo already uses.)
QtObject {
    readonly property string family: Qt.application.font.family   // system default UI font
    readonly property string mono:   "Consolas"

    readonly property int title:   18   // window / page title
    readonly property int heading: 15   // section heading
    readonly property int body:    13   // default control / label text
    readonly property int small:   12   // dense labels
    readonly property int caption: 11   // hints / captions
}
