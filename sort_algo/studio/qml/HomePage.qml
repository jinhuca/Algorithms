pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SortStudio
import UiKit

// Studio landing page: the app logo + name over three large entry cards that route
// to the Analyzer (headless benchmarks), the Visualizer (animated canvas) or the
// Knowledge base. The window wires the three signals to its page navigation.
Item {
    id: home

    signal analyzerRequested()
    signal visualizerRequested()
    signal knowledgeRequested()
    signal stabilityRequested()
    signal raceRequested()

    // A clickable workspace card: glyph, title, one-line description, hover lift.
    component EntryCard: Rectangle {
        id: card
        property string glyph: ""
        property string heading: ""
        property string blurb: ""
        signal activated()

        implicitWidth: 300
        implicitHeight: 220
        radius: 12
        color: cardArea.containsMouse ? Theme.button : Theme.panelBg
        border.width: cardArea.containsMouse ? 2 : 1
        border.color: cardArea.containsMouse ? Theme.accent : Theme.panelBorder

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 48
            spacing: 14
            Label {
                text: card.glyph
                font.family: "Segoe UI Emoji"
                font.pixelSize: 58
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                Layout.preferredHeight: 72
                Layout.fillWidth: true
            }
            Label {
                text: card.heading
                color: Theme.textPrimary
                font.pixelSize: 20; font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
            Label {
                text: card.blurb
                color: Theme.textMuted
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
        MouseArea {
            id: cardArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.activated()
        }
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 24

        Image {
            source: "qrc:/qt/qml/SortStudio/sa_logo.png"
            Layout.preferredWidth: 96; Layout.preferredHeight: 96
            sourceSize.width: 192; sourceSize.height: 192
            fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true
            Layout.alignment: Qt.AlignHCenter
        }
        Label {
            text: "Sort Algorithm Studio"
            color: Theme.textPrimary
            font.pixelSize: 30; font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }
        Label {
            text: "Choose a workspace"
            color: Theme.textMuted
            font.pixelSize: 15
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 8
        }

        GridLayout {
            columns: 3
            rowSpacing: 24
            columnSpacing: 24
            Layout.alignment: Qt.AlignHCenter

            EntryCard {
                glyph: "⏱"
                heading: "Sort Algorithm Analyzer"
                blurb: "Benchmark the sorts on large arrays — timings, comparison/swap counts and scaling curves."
                onActivated: home.analyzerRequested()
            }
            EntryCard {
                glyph: "📊"
                heading: "Sort Algorithm Visualizer"
                blurb: "Generate an array and watch a sort run step by step — compares, swaps and settled bars."
                onActivated: home.visualizerRequested()
            }
            EntryCard {
                glyph: "📚"
                heading: "Sort Knowledge Base"
                blurb: "Study each sort — how it works, stability, and best / average / worst-case complexity."
                onActivated: home.knowledgeRequested()
            }
            EntryCard {
                glyph: "🎚"
                heading: "Sort Stability"
                blurb: "See which sorts keep equal keys in their original order — input vs result, with a verdict."
                onActivated: home.stabilityRequested()
            }
            EntryCard {
                glyph: "🏁"
                heading: "Sort Race"
                blurb: "Race several sorts on the same array side by side — fewest operations wins."
                onActivated: home.raceRequested()
            }
        }
    }
}
