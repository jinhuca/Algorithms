pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SearchStudio
import UiKit

// Knowledge workspace: a searchable, category-grouped topic list on the left; the
// selected topic's article on the right, with pre-condition / complexity chips, the
// real .ixx source path, and deep-link buttons into the Visualizer / Analyzer.
Item {
    id: page

    signal visualizeRequested(string algo)
    signal benchmarkRequested(string algo)

    KnowledgeContent { id: kb }

    property string query: ""
    property string currentId: kb.topics.length ? kb.topics[0].id : ""
    readonly property var current: topicById(currentId)

    function topicById(id) {
        for (var i = 0; i < kb.topics.length; i++)
            if (kb.topics[i].id === id) return kb.topics[i];
        return null;
    }

    RowLayout {
        anchors.fill: parent
        spacing: 12

        // ---- topic list ----
        Rectangle {
            Layout.preferredWidth: 280
            Layout.fillHeight: true
            color: Theme.panelBg; border.color: Theme.panelBorder; radius: 8
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10
                TextField {
                    Layout.fillWidth: true
                    placeholderText: "Search topics…"
                    onTextChanged: page.query = text
                }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    model: kb.topics
                    ScrollBar.vertical: ScrollBar {}
                    delegate: ItemDelegate {
                        required property var modelData
                        width: ListView.view.width
                        visible: page.query.length === 0
                               || modelData.title.toLowerCase().indexOf(page.query.toLowerCase()) >= 0
                               || modelData.summary.toLowerCase().indexOf(page.query.toLowerCase()) >= 0
                        height: visible ? implicitHeight : 0
                        highlighted: page.currentId === modelData.id
                        onClicked: page.currentId = modelData.id
                        contentItem: ColumnLayout {
                            spacing: 2
                            Label { text: modelData.title; color: Theme.textPrimary; font.pixelSize: 14; font.bold: true }
                            Label { text: modelData.category; color: Theme.textMuted; font.pixelSize: 11 }
                        }
                        background: Rectangle {
                            radius: 6
                            color: parent.highlighted ? Theme.button : (parent.hovered ? Theme.buttonHover : "transparent")
                        }
                    }
                }
            }
        }

        // ---- article ----
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.panelBg; border.color: Theme.panelBorder; radius: 8
            clip: true
            Flickable {
                anchors.fill: parent
                anchors.margins: 18
                contentHeight: article.height
                clip: true
                ColumnLayout {
                    id: article
                    width: parent.width
                    spacing: 14
                    visible: page.current !== null

                    Label {
                        text: page.current ? page.current.title : ""
                        color: Theme.textPrimary; font.pixelSize: 24; font.bold: true
                    }
                    Label {
                        text: page.current ? page.current.summary : ""
                        color: Theme.textMuted; font.pixelSize: 14
                        wrapMode: Text.WordWrap; Layout.fillWidth: true
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                            model: {
                                if (!page.current) return [];
                                var c = page.current, out = [];
                                if (c.requires) out.push(c.requires);
                                if (c.best) out.push("Best " + c.best);
                                if (c.avg) out.push("Avg " + c.avg);
                                if (c.worst) out.push("Worst " + c.worst);
                                if (c.space) out.push("Space " + c.space);
                                return out;
                            }
                            delegate: Rectangle {
                                required property string modelData
                                radius: 12
                                color: Theme.canvasBg; border.color: Theme.panelBorder
                                implicitWidth: chipLbl.width + 20; implicitHeight: 26
                                Label { id: chipLbl; anchors.centerIn: parent; text: parent.modelData
                                        color: Theme.textPrimary; font.pixelSize: 12 }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.panelBorder }

                    Label {
                        text: page.current ? page.current.body : ""
                        color: Theme.textPrimary; font.pixelSize: 14
                        wrapMode: Text.WordWrap; lineHeight: 1.3; Layout.fillWidth: true
                    }

                    Label {
                        text: page.current ? "Implementation: " + page.current.source : ""
                        color: Theme.textMuted; font.pixelSize: 12; font.family: "monospace"
                        Layout.fillWidth: true; wrapMode: Text.WrapAnywhere
                    }

                    RowLayout {
                        spacing: 10
                        visible: page.current && page.current.algo.length > 0
                        UiButton {
                            text: "🔍 Visualize"
                            highlighted: true
                            onClicked: page.visualizeRequested(page.current.algo)
                        }
                        UiButton {
                            text: "⏱ Benchmark"
                            onClicked: page.benchmarkRequested(page.current.algo)
                        }
                    }
                    Item { Layout.preferredHeight: 8 }
                }
            }
        }
    }
}
