import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UiKit

// Generic modal message popup: a title, a wrapped message, and action buttons.
// By default a single "OK" that closes it; set `standardOk`/add buttons as needed.
Popup {
    id: pop
    property string title: ""
    property string message: ""
    property alias okText: okBtn.text
    signal accepted()

    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    padding: Metrics.spacingXLarge
    background: Rectangle {
        radius: Metrics.radiusLarge
        color: UiPalette.panelBg
        border.color: UiPalette.panelBorder
        border.width: Metrics.borderWidth
    }

    contentItem: ColumnLayout {
        spacing: Metrics.spacing
        Label {
            visible: pop.title.length > 0
            text: pop.title
            color: UiPalette.textPrimary
            font.pixelSize: Typography.heading
            font.family: Typography.family
            font.bold: true
        }
        Label {
            Layout.maximumWidth: 380
            Layout.fillWidth: true
            text: pop.message
            color: UiPalette.textMuted
            font.pixelSize: Typography.body
            font.family: Typography.family
            wrapMode: Text.WordWrap
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Metrics.spacingSmall
            Item { Layout.fillWidth: true }
            UiButton {
                id: okBtn
                text: "OK"
                highlighted: true
                onClicked: { pop.accepted(); pop.close(); }
            }
        }
    }
}
