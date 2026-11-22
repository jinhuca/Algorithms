pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window          // Screen (devicePixelRatio) for the HiDPI logo raster
import GraphVis
import UiKit

// Studio landing page: the app logo + name over two large entry cards that
// route to the Analyzer (headless benchmarks) or the Visualizer (interactive
// canvas). The window wires the two signals to its page navigation.
Item {
    id: home

    signal analyzerRequested()
    signal visualizerRequested()
    signal knowledgeRequested()

    // A clickable workspace card: glyph, title, one-line description, hover lift.
    // The whole card navigates (MouseArea) — no explicit button needed.
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

            // Emoji glyph in a fixed-height box so both cards' icons render at the
            // exact same size (emoji share the Segoe UI Emoji em-box, unlike a mix
            // of emoji + plain text glyphs which look different sizes).
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
                font.pixelSize: 20
                font.bold: true
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
            // Vector logo rasterised at the exact physical pixel size, so it stays
            // crisp at any display scale (not capped by a fixed PNG resolution).
            source: "qrc:/qt/qml/GraphVis/graph_logo.svg"
            Layout.preferredWidth: 96
            Layout.preferredHeight: 96
            sourceSize.width: Math.round(96 * Screen.devicePixelRatio)
            sourceSize.height: Math.round(96 * Screen.devicePixelRatio)
            fillMode: Image.PreserveAspectFit
            smooth: true
            Layout.alignment: Qt.AlignHCenter
        }
        Label {
            text: "Graph Algorithm Studio"
            color: Theme.textPrimary
            font.pixelSize: 30
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }
        Label {
            text: "Choose a workspace"
            color: Theme.textMuted
            font.pixelSize: 15
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 8
        }

        RowLayout {
            spacing: 24
            Layout.alignment: Qt.AlignHCenter

            EntryCard {
                glyph: "⏱"      // stopwatch
                heading: "Graph Algorithm Analyzer"
                blurb: "Benchmark the algorithms on large graphs — no rendering, just timings and scaling."
                onActivated: home.analyzerRequested()
            }
            EntryCard {
                glyph: "🌐"     // network / graph (nods to the 2D/3D graph canvas)
                heading: "Graph Algorithm Visualizer"
                blurb: "Build a graph and watch an algorithm run step by step on the 2D / 3D canvas."
                onActivated: home.visualizerRequested()
            }
            EntryCard {
                glyph: "📚"     // reference / study
                heading: "Graph Knowledge Base"
                blurb: "Study the algorithms and data structures — concept, complexity, implementation."
                onActivated: home.knowledgeRequested()
            }
        }
    }
}
