pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Algorithms
import UiKit

// Algorithms landing page: the app logo + name over six cards that open the
// individual studios. Search / Sort / Graph are live; Foundation / Combinatorics /
// Numerics are scaffolded studios shown with a "Coming soon" badge until their
// content lands. The window wires `studioRequested(id)` to its navigation.
Item {
    id: home

    // id: "search" | "sort" | "graph" | "foundation" | "combinatorics" | "numerics"
    signal studioRequested(string id)

    component EntryCard: Rectangle {
        id: card
        property url iconSource: ""      // the studio's app-icon svg (same art as its app icon)
        property string heading: ""
        property string studioId: ""
        property bool comingSoon: false
        signal activated()

        implicitWidth: 300
        implicitHeight: 200
        radius: 12
        color: cardArea.containsMouse ? UiPalette.button : UiPalette.panelBg
        border.width: cardArea.containsMouse ? 2 : 1
        border.color: cardArea.containsMouse ? UiPalette.accent : UiPalette.panelBorder
        opacity: card.comingSoon ? 0.72 : 1.0

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 40
            spacing: 18
            // The studio's own app-icon artwork, shown large (no tile).
            Image {
                source: card.iconSource
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 100; Layout.preferredHeight: 100
                sourceSize.width: 200; sourceSize.height: 200
                fillMode: Image.PreserveAspectFit
                smooth: true; mipmap: true
            }
            Label {
                text: card.heading
                color: UiPalette.textPrimary
                font.pixelSize: 30; font.bold: true
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }

        // "Coming soon" badge for the scaffolded studios.
        Rectangle {
            visible: card.comingSoon
            anchors { top: parent.top; right: parent.right; margins: 10 }
            radius: 10; height: 20
            width: soonLabel.implicitWidth + 18
            color: UiPalette.accent
            Label {
                id: soonLabel
                anchors.centerIn: parent
                text: "Coming soon"
                color: "#ffffff"
                font.pixelSize: 11; font.bold: true
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
        anchors.verticalCenterOffset: -48   // nudge the whole block up a little
        spacing: 20

        Image {
            source: "qrc:/qt/qml/Algorithms/Algorithm_Icon.svg"
            Layout.preferredWidth: 132; Layout.preferredHeight: 132
            sourceSize.width: 264; sourceSize.height: 264
            fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true
            Layout.alignment: Qt.AlignHCenter
        }
        Label {
            text: "Algorithms"
            color: UiPalette.textPrimary
            font.pixelSize: 40; font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }
        Label {
            text: "Choose a studio"
            color: UiPalette.textMuted
            font.pixelSize: 15
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 8
        }

        GridLayout {
            columns: 4
            rowSpacing: 24
            columnSpacing: 24
            Layout.topMargin: 28          // extra breathing room below the header
            Layout.alignment: Qt.AlignHCenter

            EntryCard {
                iconSource: "qrc:/qt/qml/SearchStudio/search_logo.svg"; heading: "Search"; studioId: "search"
                onActivated: home.studioRequested(studioId)
            }
            EntryCard {
                iconSource: "qrc:/qt/qml/SortStudio/sa_logo.svg"; heading: "Sort"; studioId: "sort"
                onActivated: home.studioRequested(studioId)
            }
            EntryCard {
                iconSource: "qrc:/qt/qml/TreeStudio/tr_logo.svg"; heading: "Tree"; studioId: "tree"
                onActivated: home.studioRequested(studioId)
            }
            EntryCard {
                iconSource: "qrc:/qt/qml/GraphVis/graph_logo.svg"; heading: "Graph"; studioId: "graph"
                onActivated: home.studioRequested(studioId)
            }
            EntryCard {
                iconSource: "qrc:/qt/qml/FoundationStudio/fo_logo.svg"; heading: "Foundation"; studioId: "foundation"
                onActivated: home.studioRequested(studioId)
            }
            EntryCard {
                iconSource: "qrc:/qt/qml/CombinatoricsStudio/cb_logo.svg"; heading: "Combinatorics"; studioId: "combinatorics"
                onActivated: home.studioRequested(studioId)
            }
            EntryCard {
                iconSource: "qrc:/qt/qml/NumericsStudio/nu_logo.svg"; heading: "Numerics"; studioId: "numerics"
                onActivated: home.studioRequested(studioId)
            }
        }
    }
}
