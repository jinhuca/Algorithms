pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SortStudio
import UiKit

// Race workspace: pick several algorithms, build one shared array, and watch them
// sort it side by side. All lanes step together (one operation per tick), so the
// lane with the fewest operations finishes first — an O(n²) sort visibly does far
// more work than an O(n log n) one. Each lane is a mini bar canvas with a progress
// bar and a finishing-place badge.
Item {
    id: page

    RaceController { id: race }

    property real raceSpeed: 20
    property var selected: page.initSel()
    function initSel() {
        var def = ["Bubble", "Insertion", "Merge", "Quick", "Heap", "Radix"];
        var m = ({});
        var all = race.algorithms;
        for (var i = 0; i < all.length; i++) m[all[i]] = def.indexOf(all[i]) >= 0;
        return m;
    }
    function chosen() {
        var out = [];
        var all = race.algorithms;
        for (var i = 0; i < all.length; i++) if (page.selected[all[i]]) out.push(all[i]);
        return out;
    }
    function setSel(a, on) { var m = Object.assign({}, page.selected); m[a] = on; page.selected = m; }
    function startRace() {
        playTimer.stop();
        race.start(page.chosen(), Math.round(sizeSlider.value), distCombo.currentText, seedSpin.value);
    }

    Timer {
        id: playTimer
        interval: Math.round(900 / page.raceSpeed)
        repeat: true
        onTriggered: { race.stepAll(); if (race.finished) running = false; }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 12

        // ---- config ----
        Rectangle {
            Layout.preferredWidth: 240
            Layout.fillHeight: true
            color: Theme.panelBg; border.color: Theme.panelBorder; radius: 8
            clip: true
            Flickable {
                anchors.fill: parent
                anchors.margins: 14
                contentWidth: width
                contentHeight: cfg.implicitHeight
                clip: true
                ScrollBar.vertical: ScrollBar { id: cfgBar; policy: ScrollBar.AsNeeded; width: 10 }
                ColumnLayout {
                    id: cfg
                    width: parent.width - cfgBar.width - 4
                    spacing: 10

                    Label { text: "Racers"; color: Theme.textMuted; font.pixelSize: 12 }
                    Repeater {
                        model: race.algorithms
                        delegate: CheckBox {
                            id: cb
                            required property string modelData
                            text: modelData
                            checked: page.selected[modelData] === true
                            onToggled: page.setSel(modelData, checked)
                            contentItem: Label { text: cb.text; color: Theme.textPrimary; font.pixelSize: 13
                                                 leftPadding: cb.indicator.width + 6; verticalAlignment: Text.AlignVCenter }
                        }
                    }

                    Label { text: "Distribution"; color: Theme.textMuted; font.pixelSize: 12 }
                    UiComboBox { id: distCombo; Layout.fillWidth: true; model: race.distributions }

                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Size"; color: Theme.textMuted; font.pixelSize: 12 }
                        Item { Layout.fillWidth: true }
                        Label { text: Math.round(sizeSlider.value); color: Theme.textPrimary; font.pixelSize: 12; font.bold: true }
                    }
                    Slider { id: sizeSlider; Layout.fillWidth: true; from: 16; to: 200; stepSize: 1; value: 60 }

                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Seed"; color: Theme.textMuted; font.pixelSize: 12 }
                        Item { Layout.fillWidth: true }
                        SpinBox { id: seedSpin; from: 1; to: 9999; value: 1; editable: true }
                    }

                    UiButton { Layout.fillWidth: true; text: "Race!"; highlighted: true; onClicked: page.startRace() }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        UiButton {
                            Layout.fillWidth: true
                            text: playTimer.running ? "Pause" : "Play"
                            enabled: race.lanes.length > 0 && !race.finished
                            onClicked: playTimer.running = !playTimer.running
                        }
                        UiButton {
                            Layout.fillWidth: true
                            text: "Reset"
                            enabled: race.lanes.length > 0
                            onClicked: { playTimer.stop(); race.resetAll(); }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Speed"; color: Theme.textMuted; font.pixelSize: 12 }
                        Slider { Layout.fillWidth: true; from: 2; to: 120; value: page.raceSpeed
                                 onMoved: page.raceSpeed = value }
                    }
                    Label {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap
                        text: "All lanes step together, one operation per tick — fewest operations wins."
                        color: Theme.textMuted; font.pixelSize: 11
                    }
                }
            }
        }

        // ---- lane grid ----
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.panelBg; border.color: Theme.panelBorder; radius: 8
            clip: true

            Label {
                anchors.centerIn: parent
                visible: race.lanes.length === 0
                text: "Pick some algorithms and press Race!"
                color: Theme.textMuted; font.pixelSize: 14
            }

            GridLayout {
                anchors.fill: parent
                anchors.margins: 12
                columns: Math.max(1, Math.min(3, race.lanes.length))
                columnSpacing: 12
                rowSpacing: 12
                visible: race.lanes.length > 0

                Repeater {
                    model: race.lanes
                    delegate: Frame {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        padding: 8
                        background: Rectangle {
                            color: Theme.canvasBg
                            border.color: modelData.rank === 1 ? Theme.barSorted : Theme.panelBorder
                            border.width: modelData.rank === 1 ? 2 : 1
                            radius: 6
                        }
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 4
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: modelData.name; color: Theme.textPrimary; font.pixelSize: 13; font.bold: true }
                                Item { Layout.fillWidth: true }
                                Label {
                                    visible: modelData.done
                                    text: "#" + modelData.rank
                                    color: modelData.rank === 1 ? Theme.barSorted : Theme.textMuted
                                    font.pixelSize: 13; font.bold: true
                                }
                                Label { text: modelData.ops + " ops"; color: Theme.textMuted; font.pixelSize: 10 }
                            }
                            SortView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                model: modelData.bars
                                maxValue: modelData.bars.maxValue
                            }
                            Rectangle {       // progress bar
                                Layout.fillWidth: true
                                height: 3; radius: 1
                                color: Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.12)
                                Rectangle {
                                    width: parent.width * modelData.progress
                                    height: parent.height; radius: 1
                                    color: modelData.done ? Theme.barSorted : Theme.accent
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
