pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SortStudio
import UiKit

// Visualizer left panel: pick the algorithm (by category) + input distribution, set
// the array size and seed, (re)generate or shuffle the data, choose which of the
// three views to show, and watch live resource use. Scrolls if it runs out of room.
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
            width: parent.width - cpBar.width - 4   // leave a dedicated gutter for the scrollbar
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
            CheckBox {
                text: "Descending order"
                // the non-comparison / distribution sorts are ascending-only here
                enabled: !["Radix", "Counting", "Bucket"].includes(panel.ctl.algorithm)
                checked: panel.ctl.descending
                onToggled: { panel.win.stopPlay(); panel.ctl.descending = checked; }
                contentItem: Label { text: parent.text
                                     color: parent.enabled ? Theme.textPrimary : Theme.textMuted
                                     font.pixelSize: 12
                                     leftPadding: parent.indicator.width + 6; verticalAlignment: Text.AlignVCenter }
            }

            Label { text: "Input distribution"; color: Theme.textMuted; font.pixelSize: 12 }
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
                from: 8; to: 200; stepSize: 1; value: 40
                onPressedChanged: if (!pressed) panel.regenerate()
            }

            RowLayout {
                Layout.fillWidth: true
                Label { text: "Seed"; color: Theme.textMuted; font.pixelSize: 12 }
                Item { Layout.fillWidth: true }
                SpinBox { id: seedSpin; from: 0; to: 99999; value: 1; editable: true
                          onValueModified: panel.regenerate() }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                UiButton { Layout.fillWidth: true; text: "Generate"; highlighted: true
                           onClicked: panel.regenerate() }
                UiButton { Layout.fillWidth: true; text: "Shuffle"
                           onClicked: { panel.win.stopPlay(); panel.ctl.shuffle(); } }
            }

            Label { text: "Custom array (type or paste)"; color: Theme.textMuted; font.pixelSize: 12 }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                TextField {
                    id: customField
                    Layout.fillWidth: true
                    placeholderText: "e.g. 5, 3, 8, 1, 9, 2"
                    onAccepted: { panel.win.stopPlay(); panel.ctl.setValuesFromText(text); }
                }
                UiButton {
                    text: "Apply"
                    onClicked: { panel.win.stopPlay(); panel.ctl.setValuesFromText(customField.text); }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.panelBorder }

            Label { text: "View"; color: Theme.textMuted; font.pixelSize: 12 }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: [{ k: "bars", t: "Bars" }, { k: "dots", t: "Dots" }, { k: "strip", t: "Strip" }]
                    delegate: UiToggleButton {
                        required property var modelData
                        Layout.fillWidth: true
                        autoExclusive: true
                        checked: panel.win.viewMode === modelData.k
                        text: modelData.t
                        onClicked: panel.win.viewMode = modelData.k
                    }
                }
            }
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
            CheckBox {
                text: "Sound"
                checked: panel.win.soundOn
                onToggled: panel.win.soundOn = checked
                contentItem: Label { text: parent.text; color: Theme.textPrimary; font.pixelSize: 12
                                     leftPadding: parent.indicator.width + 6; verticalAlignment: Text.AlignVCenter }
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "Tip: switch views mid-run — the strip view makes the final spectrum sweep obvious, the dots view shows the sorted diagonal forming."
                color: Theme.textMuted
                font.pixelSize: 11
            }

            // Live resource use (samples only while the Visualizer is on screen).
            LiveUtilization {
                Layout.fillWidth: true
                active: panel.win.page === "visualizer"
                expanded: panel.win.monitorExpanded
                onToggled: panel.win.monitorExpanded = !panel.win.monitorExpanded
            }
        }
    }
}
