import QtQuick
import QtQuick.Controls
import UiKit

// Generic dropdown styled from the shared tokens, matching the Figma ComboBox
// mock: a rounded field with a chevron indicator, a rounded popup with tall rows,
// a full-width highlight bar on the current row, and a rounded scrollbar.
ComboBox {
    id: ctl
    implicitHeight: Metrics.controlHeight
    font.pixelSize: Typography.body
    font.family: Typography.family

    // --- field text ---
    contentItem: Text {
        leftPadding: Metrics.spacingLarge
        rightPadding: ctl.indicator.width + Metrics.spacing
        text: ctl.displayText
        font: ctl.font
        color: UiPalette.textPrimary
        opacity: ctl.enabled ? 1.0 : 0.5
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    // --- chevron indicator (drawn so it tracks the token colour) ---
    indicator: Canvas {
        id: chevron
        x: ctl.width - width - Metrics.spacingLarge
        y: (ctl.height - height) / 2
        width: 12
        height: 8
        Connections {
            target: UiPalette
            function onDarkChanged() { chevron.requestPaint() }
        }
        onPaint: {
            const c = getContext("2d");
            c.reset();
            c.strokeStyle = UiPalette.textMuted;
            c.lineWidth = 1.6;
            c.lineCap = "round";
            c.lineJoin = "round";
            c.beginPath();
            c.moveTo(1, 1.5);
            c.lineTo(width / 2, height - 1.5);
            c.lineTo(width - 1, 1.5);
            c.stroke();
        }
    }

    // --- field background ---
    background: Rectangle {
        radius: Metrics.radius            // match UiButton's corner radius
        color: ctl.enabled ? UiPalette.button : Qt.darker(UiPalette.button, 1.05)
        border.width: Metrics.borderWidth
        border.color: ctl.activeFocus ? UiPalette.accent : UiPalette.panelBorder
    }

    // --- popup rows ---
    delegate: ItemDelegate {
        id: row
        // Declaring any required model property switches the delegate to
        // required-property mode, so `modelData` must be declared too (the context
        // property is no longer injected). All app models here are JS arrays, so
        // `modelData` is the element: a string, or an object indexed by textRole.
        required property var modelData
        required property int index
        width: ctl.width
        height: Math.round(Metrics.controlHeight * 1.4)   // tall, generous rows
        padding: 0
        contentItem: Text {
            leftPadding: Metrics.spacingLarge
            rightPadding: Metrics.spacingLarge
            text: ctl.textRole.length > 0 ? row.modelData[ctl.textRole] : row.modelData
            font.pixelSize: Typography.body
            font.family: Typography.family
            color: row.highlighted ? UiPalette.selectionText : UiPalette.textPrimary
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        highlighted: ctl.highlightedIndex === index
        background: Rectangle {
            color: row.highlighted ? UiPalette.selection : "transparent"
        }
    }

    // --- popup ---
    popup: Popup {
        y: ctl.height + Metrics.spacingXSmall
        width: ctl.width
        implicitHeight: Math.min(contentItem.implicitHeight + 2 * padding, 320)
        padding: Metrics.spacingXSmall
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: ctl.popup.visible ? ctl.delegateModel : null
            currentIndex: ctl.highlightedIndex
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 6
                contentItem: Rectangle {
                    implicitWidth: 6
                    radius: 3
                    color: UiPalette.accent
                    opacity: parent.pressed ? 0.9 : 0.6
                }
            }
        }
        background: Rectangle {
            radius: Metrics.radiusLarge
            color: UiPalette.panelBg
            border.color: UiPalette.panelBorder
            border.width: Metrics.borderWidth
        }
    }
}
