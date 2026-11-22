pragma ComponentBehavior: Bound
import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import GraphVis
import UiKit

// Knowledge workspace: a curated, read-only reference for the algorithms and data
// structures this studio implements. Master–detail — a category-grouped, searchable
// topic browser on the left; the selected topic's Markdown article on the right,
// with complexity/property chips, the real .ixx source path, and deep-link buttons
// into the Visualizer / Analyzer. Content lives in KnowledgeContent.qml.
Item {
    id: page

    // Deep links wired by the window (see Main.qml).
    signal visualizeRequested(string algo)
    signal benchmarkRequested(string algo)

    KnowledgeContent { id: kb }

    property string query: ""
    property string currentId: ""
    property var current: page.topicById(page.currentId)

    function topicById(id) {
        for (var i = 0; i < kb.topics.length; i++)
            if (kb.topics[i].id === id) return kb.topics[i];
        return null;
    }
    // Topics filtered by the search text, grouped by category (first-seen order).
    function computeGroups(q) {
        var ql = (q || "").toLowerCase();
        var order = [], map = ({});
        for (var i = 0; i < kb.topics.length; i++) {
            var t = kb.topics[i];
            if (ql.length && t.title.toLowerCase().indexOf(ql) < 0
                          && t.summary.toLowerCase().indexOf(ql) < 0) continue;
            if (!map[t.category]) { map[t.category] = []; order.push(t.category); }
            map[t.category].push(t);
        }
        return order.map(function (c) { return { name: c, items: map[c] }; });
    }
    property var groups: page.computeGroups(page.query)

    Settings {
        id: settings
        category: "knowledge"
        property var splitState           // SplitView.saveState() blob (browser width)
        property string topicId           // last-selected topic
    }
    Component.onCompleted: {
        var t = (settings.topicId && page.topicById(settings.topicId)) ? settings.topicId
               : (kb.topics.length ? kb.topics[0].id : "");
        page.currentId = t;
    }
    Component.onDestruction: settings.topicId = page.currentId

    // A small rounded tag for complexity / properties.
    component Chip: Rectangle {
        property string label: ""
        implicitHeight: 22
        implicitWidth: chipText.implicitWidth + 18
        radius: 11
        color: "transparent"
        border.color: Theme.panelBorder
        border.width: 1
        Label {
            id: chipText
            anchors.centerIn: parent
            text: parent.label
            color: Theme.textMuted
            font.pixelSize: 12
        }
    }

    SplitView {
        id: kSplit
        anchors.fill: parent
        orientation: Qt.Horizontal

        Component.onCompleted: if (settings.splitState) restoreState(settings.splitState)
        Component.onDestruction: settings.splitState = saveState()

        handle: Rectangle {
            id: kHandle
            implicitWidth: 14; implicitHeight: 14
            color: "transparent"
            readonly property bool active: SplitHandle.hovered || SplitHandle.pressed
            readonly property bool held: SplitHandle.pressed
            Rectangle {
                anchors.centerIn: parent
                width: 2; height: 30; radius: 1
                color: kHandle.held ? Theme.accent : (kHandle.active ? Theme.panelBorder : "transparent")
            }
        }

        // ---- topic browser ----
        Frame {
            SplitView.preferredWidth: 280
            SplitView.minimumWidth: 220
            background: Rectangle { color: Theme.panelBg; border.color: Theme.panelBorder; radius: 8 }

            ColumnLayout {
                anchors.fill: parent
                spacing: 8

                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: "Search topics…"
                    text: page.query
                    selectByMouse: true
                    onTextChanged: page.query = text
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: page.groups
                            delegate: ColumnLayout {
                                id: grp
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 2

                                Label {
                                    text: grp.modelData.name.toUpperCase()
                                    color: Theme.textMuted
                                    font.pixelSize: 11; font.bold: true
                                    Layout.topMargin: 8; Layout.leftMargin: 4
                                }
                                Repeater {
                                    model: grp.modelData.items
                                    delegate: Rectangle {
                                        id: row
                                        required property var modelData
                                        Layout.fillWidth: true
                                        implicitHeight: 32
                                        radius: 6
                                        readonly property bool sel: page.currentId === row.modelData.id
                                        color: row.sel ? Theme.button
                                                        : (rowArea.containsMouse ? Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.06)
                                                                                 : "transparent")
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 6; anchors.rightMargin: 6
                                            spacing: 6
                                            Label { text: row.modelData.glyph; font.family: "Segoe UI Emoji"; font.pixelSize: 14 }
                                            Label {
                                                Layout.fillWidth: true
                                                text: row.modelData.title
                                                color: Theme.textPrimary
                                                font.pixelSize: 13
                                                elide: Text.ElideRight
                                            }
                                        }
                                        MouseArea {
                                            id: rowArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: page.currentId = row.modelData.id
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---- article ----
        Frame {
            SplitView.fillWidth: true
            SplitView.minimumWidth: 360
            background: Rectangle { color: Theme.panelBg; border.color: Theme.panelBorder; radius: 8 }

            ScrollView {
                anchors.fill: parent
                clip: true
                contentWidth: availableWidth

                ColumnLayout {
                    width: parent.width
                    spacing: 12

                    // Title + deep-link buttons.
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Label {
                            text: page.current ? (page.current.glyph + "  " + page.current.title) : ""
                            color: Theme.textPrimary
                            font.pixelSize: 24; font.bold: true
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                        UiButton {
                            visible: !!(page.current && page.current.related)
                            text: "Visualize"
                            onClicked: if (page.current && page.current.related) page.visualizeRequested(page.current.related.visualize)
                        }
                        UiButton {
                            visible: !!(page.current && page.current.related)
                            text: "Benchmark"
                            onClicked: if (page.current && page.current.related) page.benchmarkRequested(page.current.related.benchmark)
                        }
                    }

                    // category · source path
                    Label {
                        Layout.fillWidth: true
                        visible: !!page.current
                        text: page.current ? (page.current.category + "  ·  " + page.current.source) : ""
                        color: Theme.textMuted
                        font.pixelSize: 12
                        wrapMode: Text.WrapAnywhere
                    }

                    // complexity + property chips
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: {
                                if (!page.current) return [];
                                var a = [];
                                if (page.current.complexity && page.current.complexity.length) a.push(page.current.complexity);
                                return a.concat(page.current.props || []);
                            }
                            delegate: Chip {
                                required property var modelData
                                label: modelData
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.panelBorder }

                    // Markdown article body.
                    Text {
                        Layout.fillWidth: true
                        visible: !!page.current
                        text: page.current ? page.current.body : ""
                        textFormat: Text.MarkdownText
                        wrapMode: Text.WordWrap
                        color: Theme.textPrimary
                        linkColor: Theme.accent
                        font.pixelSize: 14
                        onLinkActivated: (link) => Qt.openUrlExternally(link)
                    }

                    // References.
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 4
                        visible: !!(page.current && page.current.references && page.current.references.length)
                        Label { text: "References"; color: Theme.textPrimary; font.pixelSize: 14; font.bold: true }
                        Repeater {
                            model: page.current && page.current.references ? page.current.references : []
                            delegate: Text {
                                required property var modelData
                                Layout.fillWidth: true
                                text: '• <a href="' + modelData.url + '">' + modelData.title + '</a>'
                                textFormat: Text.StyledText
                                wrapMode: Text.WordWrap
                                color: Theme.textMuted
                                linkColor: Theme.accent
                                font.pixelSize: 13
                                onLinkActivated: (link) => Qt.openUrlExternally(link)
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }   // push content to the top
                }
            }
        }
    }
}
