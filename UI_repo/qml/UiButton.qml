import QtQuick
import QtQuick.Controls
import UiKit

// Generic push button styled from the shared tokens. The ACTIVE look (accent
// fill) is shown when the button is `highlighted` (a primary action) OR `checked`
// (a toggle that is on), so every toggle reads consistently. A disabled button is
// clearly recessed with low-contrast text. Drop-in for QtQuick.Controls Button.
Button {
    id: ctl
    implicitHeight: Metrics.controlHeight
    font.pixelSize: Typography.body
    font.family: Typography.family
    hoverEnabled: true

    // On = primary action or a checked toggle.
    readonly property bool active: highlighted || checked

    contentItem: Text {
        text: ctl.text
        font: ctl.font
        color: !ctl.enabled ? UiPalette.textDisabled
               : ctl.active ? UiPalette.accentText
               : UiPalette.buttonText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: Metrics.radius
        color: !ctl.enabled ? UiPalette.buttonDisabled
               : ctl.active ? (ctl.down ? Qt.darker(UiPalette.accent, 1.2) : UiPalette.accent)
               : (ctl.down ? UiPalette.buttonDown
                  : ctl.hovered ? UiPalette.buttonHover : UiPalette.button)
        border.width: (ctl.active && ctl.enabled) ? 0 : Metrics.borderWidth
        border.color: ctl.enabled ? UiPalette.panelBorder : UiPalette.buttonBorderDisabled
    }
}
