import QtQuick
import QtQuick.Controls
import UiKit

// Generic checkable toggle button — accent-filled while `checked`. Use for on/off
// or mutually-exclusive (autoExclusive) selections.
Button {
    id: ctl
    checkable: true
    implicitHeight: Metrics.controlHeight
    font.pixelSize: Typography.body
    font.family: Typography.family
    hoverEnabled: true

    contentItem: Text {
        text: ctl.text
        font: ctl.font
        color: ctl.checked ? UiPalette.accentText : UiPalette.buttonText
        opacity: ctl.enabled ? 1.0 : 0.5
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: Metrics.radius
        color: ctl.checked
                   ? (ctl.down ? Qt.darker(UiPalette.accent, 1.2) : UiPalette.accent)
                   : (ctl.hovered ? UiPalette.buttonHover : UiPalette.button)
        border.width: ctl.checked ? 0 : Metrics.borderWidth
        border.color: UiPalette.panelBorder
        opacity: ctl.enabled ? 1.0 : 0.6
    }
}
