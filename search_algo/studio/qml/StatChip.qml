import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SearchStudio

// A small labelled stat tile: a caption above a value. Used for the live
// probe / step counters on the run bar.
Rectangle {
    id: chip
    property string caption: ""
    property string value: ""
    implicitWidth: col.implicitWidth + 24
    implicitHeight: 44
    radius: 8
    color: Theme.panelBg
    border.color: Theme.panelBorder

    ColumnLayout {
        id: col
        anchors.centerIn: parent
        spacing: 0
        Label {
            text: chip.caption
            color: Theme.textMuted
            font.pixelSize: 10
            Layout.alignment: Qt.AlignHCenter
        }
        Label {
            text: chip.value
            color: Theme.textPrimary
            font.pixelSize: 15; font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
