import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import CombinatoricsStudio
import UiKit

// Combinatorics Algorithm Studio content (skeleton). Chrome-free, like the other studios'
// Roots, so the Algorithms umbrella can host it. Exposes `pageTitle` + `titleControls`
// (none yet) for the umbrella title bar.
Item {
    id: root
    property string pageTitle: "Combinatorics Algorithm Studio"
    property Component titleControls: null

    // Identity shown in the host (umbrella) title bar when this studio is active.
    // (QML constant mirroring the project version; not the build-stamped version.h.)
    readonly property string iconSource: "qrc:/qt/qml/CombinatoricsStudio/cb_logo.svg"
    readonly property string version: "0.1.0"

    PlaceholderController { id: ctl }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 16
        width: Math.min(560, root.width - 96)

        Image {
            source: "qrc:/qt/qml/CombinatoricsStudio/cb_logo.svg"
            Layout.preferredWidth: 88; Layout.preferredHeight: 88
            Layout.alignment: Qt.AlignHCenter
            sourceSize.width: 176; sourceSize.height: 176
            fillMode: Image.PreserveAspectFit; smooth: true
        }
        Label {
            text: ctl.studioName + " Algorithm Studio"
            color: UiPalette.textPrimary
            font.pixelSize: 26; font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }
        Label {
            text: "Skeleton studio — the core is wired in; workspaces are coming soon."
            color: UiPalette.textMuted
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
