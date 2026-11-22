pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SearchStudio
import UiKit

// Visualizer left panel: pick the algorithm (by category) + input distribution, set the
// array size and seed, choose the target (a preset position or a custom value), and
// (re)generate. Scrolls if it runs out of room.
Rectangle {
    id: panel
    property var win
    property var ctl

    color: Theme.panelBg
    border.color: Theme.panelBorder
    radius: 8

    function regenerate() {
        panel.win.stopPlay();
        panel.ctl.generate(Math.round(sizeSlider.value), seedSpin.value);
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 14
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        ScrollBar.vertical: ScrollBar { id: cpBar; policy: ScrollBar.AsNeeded; width: 10 }

        ColumnLayout {
            id: col
            width: parent.width - cpBar.width - 4
            spacing: 14

            Label { text: "Category"; color: Theme.textMuted; font.pixelSize: 12 }
            UiComboBox {
                id: catCombo
                Layout.fillWidth: true
                model: panel.ctl.categories
                currentIndex: Math.max(0, panel.ctl.categories.indexOf(panel.ctl.categoryOf(panel.ctl.algorithm)))
                onActivated: { panel.win.stopPlay(); panel.ctl.algorithm = panel.ctl.algorithmsIn(model[currentIndex])[0]; }
            }

            Label { text: "Algorithm"; color: Theme.textMuted; font.pixelSize: 12 }
            UiComboBox {
                id: algoCombo
                Layout.fillWidth: true
                readonly property var algoList: panel.ctl.algorithmsIn(panel.ctl.categoryOf(panel.ctl.algorithm))
                model: algoList
                currentIndex: Math.max(0, algoList.indexOf(panel.ctl.algorithm))
                onActivated: { panel.win.stopPlay(); panel.ctl.algorithm = model[currentIndex]; }
            }

            Label { text: "Input distribution (sorted)"; color: Theme.textMuted; font.pixelSize: 12 }
            UiComboBox {
                id: distCombo
                Layout.fillWidth: true
                model: panel.ctl.distributions
                currentIndex: Math.max(0, panel.ctl.distributions.indexOf(panel.ctl.distribution))
                onActivated: { panel.ctl.distribution = model[currentIndex]; panel.regenerate(); }
            }

            RowLayout {
                Layout.fillWidth: true
                Label { text: "Size"; color: Theme.textMuted; font.pixelSize: 12 }
                Item { Layout.fillWidth: true }
                Label { text: Math.round(sizeSlider.value); color: Theme.textPrimary; font.pixelSize: 12; font.bold: true }
            }
            Slider {
                id: sizeSlider
                Layout.fillWidth: true
                from: 4; to: 160; stepSize: 1; value: 32
                onPressedChanged: if (!pressed) panel.regenerate()
            }

            RowLayout {
                Layout.fillWidth: true
                Label { text: "Seed"; color: Theme.textMuted; font.pixelSize: 12 }
                Item { Layout.fillWidth: true }
                SpinBox { id: seedSpin; from: 0; to: 99999; value: 1; editable: true
                          onValueModified: panel.regenerate() }
            }

            UiButton { Layout.fillWidth: true; text: "Generate"; highlighted: true
                       onClicked: panel.regenerate() }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.panelBorder }

            Label { text: "Target"; color: Theme.textMuted; font.pixelSize: 12 }
            UiComboBox {
                id: targetCombo
                Layout.fillWidth: true
                model: panel.ctl.targetModes
                currentIndex: Math.max(0, panel.ctl.targetModes.indexOf(panel.ctl.targetMode))
                onActivated: { panel.win.stopPlay(); panel.ctl.targetMode = model[currentIndex]; }
            }
            Label {
                Layout.fillWidth: true
                text: "Current target: " + Number(panel.ctl.target).toFixed(2)
                color: Theme.textPrimary; font.pixelSize: 12; font.bold: true
            }
            Label { text: "Custom target"; color: Theme.textMuted; font.pixelSize: 12 }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                TextField {
                    id: targetField
                    Layout.fillWidth: true
                    placeholderText: "e.g. 42.5"
                    onAccepted: { var v = parseFloat(text); if (!isNaN(v)) { panel.win.stopPlay(); panel.ctl.setCustomTarget(v); } }
                }
                UiButton {
                    text: "Set"
                    onClicked: { var v = parseFloat(targetField.text); if (!isNaN(v)) { panel.win.stopPlay(); panel.ctl.setCustomTarget(v); } }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.panelBorder }

            CheckBox {
                text: "Show values"
                checked: panel.win.showValues
                onToggled: panel.win.showValues = checked
                contentItem: Label { text: parent.text; color: Theme.textPrimary; font.pixelSize: 12
                                     leftPadding: parent.indicator.width + 6; verticalAlignment: Text.AlignVCenter }
            }
            CheckBox {
                text: "Show pseudocode"
                checked: panel.win.showPseudocode
                onToggled: panel.win.showPseudocode = checked
                contentItem: Label { text: parent.text; color: Theme.textPrimary; font.pixelSize: 12
                                     leftPadding: parent.indicator.width + 6; verticalAlignment: Text.AlignVCenter }
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "The array is always sorted so every search is valid input. Yellow = the current probe, blue = still-in-window candidates, dimmed = discarded, green = the found target."
                color: Theme.textMuted
                font.pixelSize: 11
            }
        }
    }
}
