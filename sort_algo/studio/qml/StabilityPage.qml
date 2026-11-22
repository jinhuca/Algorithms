pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SortStudio
import UiKit

// Stability workspace: shows, for the chosen sort, the input vs the sorted result
// with every bar coloured by its ORIGINAL position (a left→right rainbow on input).
// A sort is stable when equal-key bars keep their input order — so within each
// equal-height group the rainbow stays locally ascending for a stable sort and gets
// scrambled for an unstable one. A verdict banner states the outcome.
Item {
    id: page

    StabilityController { id: sc }

    // Colour a bar by its original position: a rainbow red→violet across the array.
    function originColor(origin, n) {
        return Qt.hsva(0.82 * (n > 1 ? origin / (n - 1) : 0), 0.65, 0.95, 1);
    }

    // One labelled strip of bars. `rows` is a [{key, origin}] list.
    component Strip: ColumnLayout {
        id: strip
        property string title: ""
        property var rows: []
        spacing: 6
        Label { text: strip.title; color: Theme.textMuted; font.pixelSize: 12 }
        Frame {
            Layout.fillWidth: true
            Layout.fillHeight: true
            padding: 8
            background: Rectangle { color: Theme.canvasBg; border.color: Theme.panelBorder; radius: 8 }
            Item {
                anchors.fill: parent
                readonly property int n: strip.rows.length
                readonly property real gap: n > 80 ? 1 : (n > 40 ? 2 : 3)
                readonly property real bw: n > 0 ? Math.max(1, (width - gap * (n - 1)) / n) : 0
                Repeater {
                    model: strip.rows
                    delegate: Rectangle {
                        required property int index
                        required property var modelData
                        width: parent.bw
                        x: index * (parent.bw + parent.gap)
                        height: Math.max(2, (modelData.key / sc.keyLevels) * parent.height)
                        y: parent.height - height
                        radius: parent.bw > 6 ? 2 : 0
                        color: page.originColor(modelData.origin, sc.count)
                        antialiasing: true
                        Behavior on x { enabled: sc.count <= 80; NumberAnimation { duration: 450; easing.type: Easing.InOutCubic } }
                        Behavior on height { enabled: sc.count <= 80; NumberAnimation { duration: 300 } }
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // ---- controls ----
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: ctlRow.implicitHeight + 20
            color: Theme.panelBg; border.color: Theme.panelBorder; radius: 8
            RowLayout {
                id: ctlRow
                anchors.fill: parent
                anchors.margins: 10
                spacing: 12
                Label { text: "Algorithm"; color: Theme.textMuted; font.pixelSize: 12 }
                UiComboBox {
                    Layout.preferredWidth: 140
                    model: sc.algorithms
                    currentIndex: Math.max(0, sc.algorithms.indexOf(sc.algorithm))
                    onActivated: sc.algorithm = model[currentIndex]
                }
                Label { text: "Size"; color: Theme.textMuted; font.pixelSize: 12 }
                Slider {
                    id: sizeSlider
                    Layout.preferredWidth: 150
                    from: 6; to: 96; stepSize: 1; value: 32
                    onPressedChanged: if (!pressed) sc.run(Math.round(value), keysSpin.value, seedSpin.value)
                }
                Label { text: Math.round(sizeSlider.value); color: Theme.textPrimary; font.pixelSize: 12; font.bold: true }
                Label { text: "Distinct keys"; color: Theme.textMuted; font.pixelSize: 12 }
                SpinBox {
                    id: keysSpin; from: 2; to: 12; value: 4
                    onValueModified: sc.run(Math.round(sizeSlider.value), value, seedSpin.value)
                }
                Label { text: "Seed"; color: Theme.textMuted; font.pixelSize: 12 }
                SpinBox {
                    id: seedSpin; from: 1; to: 9999; value: 1; editable: true
                    onValueModified: sc.run(Math.round(sizeSlider.value), keysSpin.value, value)
                }
                UiButton {
                    text: "Shuffle"
                    onClicked: { seedSpin.value = 1 + Math.floor(Math.random() * 9999);
                                 sc.run(Math.round(sizeSlider.value), keysSpin.value, seedSpin.value); }
                }
                Item { Layout.fillWidth: true }
            }
        }

        // ---- verdict banner ----
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 44
            radius: 8
            readonly property color tone: sc.stable ? Theme.barSorted : Theme.barSwap
            color: Qt.rgba(tone.r, tone.g, tone.b, 0.15)
            border.color: tone
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10
                Label {
                    text: sc.stable ? "✓" : "✗"
                    color: sc.stable ? Theme.barSorted : Theme.barSwap
                    font.pixelSize: 18; font.bold: true
                }
                Label {
                    Layout.fillWidth: true
                    text: sc.algorithm + " sort is " + (sc.stable ? "STABLE" : "NOT stable")
                          + " — " + (sc.stable
                              ? "equal-key bars kept their original (rainbow) order."
                              : "equal-key bars were reordered (rainbow scrambled within a group).")
                    color: Theme.textPrimary; font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }
            }
        }

        Strip { Layout.fillWidth: true; Layout.fillHeight: true; title: "Input (colour = original position)"; rows: sc.before }
        Strip { Layout.fillWidth: true; Layout.fillHeight: true; title: "After " + sc.algorithm + " sort"; rows: sc.after }
    }
}
