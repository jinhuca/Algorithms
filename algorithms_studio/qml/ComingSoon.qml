pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UiKit

// Placeholder shown when a scaffolded-but-not-yet-built studio (Foundation /
// Combinatorics / Numerics) is opened from the home page. Replaced by the real
// studio content once each project is scaffolded.
Item {
    id: page
    property string studioName: ""

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 16
        width: Math.min(520, page.width - 96)

        Label {
            text: "🚧"
            font.family: "Segoe UI Emoji"; font.pixelSize: 64
            Layout.alignment: Qt.AlignHCenter
        }
        Label {
            text: page.studioName + " Studio"
            color: UiPalette.textPrimary
            font.pixelSize: 26; font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }
        Label {
            text: "This studio is scaffolded but not built yet. Check back soon."
            color: UiPalette.textMuted
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
