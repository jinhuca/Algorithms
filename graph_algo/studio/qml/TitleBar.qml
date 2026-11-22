pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import GraphVis
import UiKit

// Single integrated title bar for the frameless window: app title, the primary
// pickers (Category / Algorithm / Data Set + load/save/clear), the light/dark
// toggle, and the minimise / maximise / close buttons. The window owns the
// behaviour and wires it through the signals + the win/ctl/graph refs below.
Rectangle {
    id: bar
    height: 42
    color: _title_bar_defs.dark_background

    property string title: ""
    property string page: "visualizer"   // "home" | "visualizer" | "analyzer" — gates the middle pickers
    property string version: ""     // Major.Minor.Patch.Build, shown dimmed after the title
    property string themeName: ""   // current UI theme (see UiPalette.themeNames)
    property var themeNames: []     // available themes, for the picker dropdown
    property color accentColor: "transparent"   // effective accent, shown in the swatch
    property bool accentIsCustom: false          // true when a user override is active
    property bool maximized: false

    // Window + model refs (same set the control panel takes) so the title bar can
    // host the algorithm + data-set pickers that used to live in the panel / run bar.
    required property var win
    required property var ctl
    required property var graph
    required property var graph3d
    required property var dialogs

    signal moveRequested()
    signal maximizeToggled()
    signal minimizeRequested()
    signal closeRequested()
    signal homeRequested()
    signal themeSelected(string name)
    signal accentPickRequested()
    signal accentResetRequested()

    MouseArea {
        anchors.fill: parent
        onPressed: bar.moveRequested()
        onDoubleClicked: bar.maximizeToggled()
    }

    // Hairline under the bar — separates the light (white) chrome from the content
    // below; transparent in dark so the dark look is unchanged.
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: _title_bar_defs.bar_bottom_border
    }

    component AppLabel: Label {
        color: _title_bar_defs.title_color
        font.pixelSize: _title_bar_defs.title_font_pixel_size
        font.bold: _title_bar_defs.title_bold
        font.capitalization: Font.Capitalize
        elide: Text.ElideRight
    }

    component VersionLabel: Label {
        Layout.preferredWidth: _title_bar_defs.version_label_width
        color: _title_bar_defs.version_text_color
        font.pixelSize: _title_bar_defs.version_font_size
        font.bold: _title_bar_defs.version_font_bold
        Layout.alignment: Qt.AlignVCenter
    }

    component CategoryLabel: Label {
        color: _title_bar_defs.label_color
        font.pixelSize: _title_bar_defs.label_pixel_size
        font.bold: _title_bar_defs.label_bold
        wrapMode: _title_bar_defs.label_wrap
    }

    component ActionBtn: UiButton {
        Layout.preferredWidth: _title_bar_defs.actionBtn_preferred_width
        Layout.alignment: _title_bar_defs.actionBtn_vcenter
        leftPadding: _title_bar_defs.actionBtn_left_padding
        rightPadding: _title_bar_defs.actionBtn_right_padding
    }

    component WinBtn: ToolButton {
        implicitWidth: 46; implicitHeight: 38
        property color hoverColor: _title_bar_defs.winbtn_hover_color
        // Text colour while hovered — defaults to the normal colour (min / max keep
        // their theme text on a light hover); the close button overrides it to white
        // so its glyph stays legible on the red hover fill.
        property color hoverTextColor: _title_bar_defs.winbtn_text_color
        contentItem: Text {
            text: parent.text
            color: parent.hovered ? parent.hoverTextColor : _title_bar_defs.winbtn_text_color
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle { color: parent.hovered ? parent.hoverColor : "transparent" }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        spacing: 8

        // App icon, before the title (like VS's window icon). Same logo embedded
        // as the .exe / taskbar icon; kept visible alongside the title.
        Image {
            source: "qrc:/qt/qml/GraphVis/ga_logo.png"
            Layout.preferredWidth: _title_bar_defs.icon_size
            Layout.preferredHeight: _title_bar_defs.icon_size
            Layout.alignment: Qt.AlignVCenter
            sourceSize.width: _title_bar_defs.icon_size * 2   // 2× for crisp HiDPI downscale
            sourceSize.height: _title_bar_defs.icon_size * 2
            fillMode: Image.PreserveAspectFit
            smooth: true; mipmap: true
        }

        // App name (plays the role of VS's app icon): always kept visible. The
        // middle picker region below collapses/clips first, so the title and the
        // window buttons never get pushed off when the window is narrowed.
        AppLabel { text: bar.title }

        // Middle region (version + pickers): flexible + clipping, like VS's toolbar
        // area — it takes the slack when the bar is wide and collapses/clips from
        // the right when the window is narrowed, so the title + window buttons stay.
        Item {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.fillHeight: true
            Layout.preferredWidth: midRow.implicitWidth
            clip: true
            RowLayout {
                id: midRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Version (Major.Minor.Patch.Build) between dimmed vertical-bar separators.
                Rectangle {
                    visible: bar.version.length > 0
                    Layout.leftMargin: 6; Layout.rightMargin: 6
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 3; Layout.preferredHeight: 20
                    color: _title_bar_defs.separator_color
                }
                VersionLabel {
                    visible: bar.version.length > 0
                    text: bar.version
                }
                Rectangle {
                    visible: bar.version.length > 0
                    Layout.leftMargin: 6; Layout.rightMargin: 6
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 3; Layout.preferredHeight: 20
                    color: _title_bar_defs.separator_color
                }

                // Home button — shown on a module page so the user can always get
                // back to the Studio landing. (The title already names the module.)
                ActionBtn {
                    visible: bar.page !== "home"
                    Text {
                        text: qsTr("Home")
                        font.bold: true
                        font.pixelSize: 15
                        color: "white"
                        anchors.centerIn: parent
                    }
                    onClicked: bar.homeRequested()
                    ToolTip.visible: hovered
                    ToolTip.text: "Back to the Studio home"
                }

                // Visualizer-only pickers (algorithm + data set): hidden on the home
                // and analyzer pages, which don't run the step-by-step canvas.
                RowLayout {
                    visible: bar.page === "visualizer"
                    spacing: 8

                // Category
                CategoryLabel { text: "Category" }
                UiComboBox {
                    Layout.preferredWidth: 96
                    Layout.alignment: Qt.AlignVCenter
                    model: bar.win.algoCats
                    currentIndex: Math.max(0, bar.win.algoCats.indexOf(bar.win.catOf(bar.win.activeAlgo)))
                    onActivated: bar.win.activeAlgo = bar.win.algosByCat[currentText][0]
                    ToolTip.visible: hovered
                    ToolTip.text: "Algorithm category"
                }

                // Algorithm
                CategoryLabel { text: "Algorithm" }
                UiComboBox {
                    Layout.preferredWidth: 124
                    Layout.alignment: Qt.AlignVCenter
                    model: bar.win.algosByCat[bar.win.catOf(bar.win.activeAlgo)]
                    currentIndex: Math.max(0, bar.win.algosByCat[bar.win.catOf(bar.win.activeAlgo)].indexOf(bar.win.activeAlgo))
                    onActivated: bar.win.activeAlgo = currentText
                    ToolTip.visible: hovered
                    ToolTip.text: "Algorithm Run executes"
                }

                // Recent files (most-recent first) head the list, then the built-in samples;
                // the field shows the current document regardless of the dropdown's index.
                CategoryLabel { text: "Data Set" }
                UiComboBox {
                    id: sampleBox
                    Layout.preferredWidth: 140
                    Layout.alignment: Qt.AlignVCenter
                    readonly property var recentNames: bar.win.recentFiles.map(function (e) { return e.name; })
                    model: recentNames.concat(bar.ctl.sampleNames())
                    displayText: bar.win.docName.replace(/\.json$/i, "")
                    onActivated: {
                        var n = sampleBox.recentNames.length
                        if (currentIndex < n) {
                            // A recent file — reopen it (no-op if it's already current).
                            var rf = bar.win.recentFiles[currentIndex];
                            if (!rf || rf.path === bar.win.currentFile) return;
                            bar.win.confirmUnsaved(function () {
                                bar.win.stopPlay(); bar.graph.edgeMode = false;
                                bar.win.currentFile = rf.path; bar.win.docName = bar.win.baseName(rf.path);
                                bar.win.addRecent(rf.path);
                                bar.ctl.loadFromFileAsync(rf.path);
                            });
                        }
                        else {
                            // A built-in sample (synchronous; behind the 3D "Preparing…" gate).
                            var name = currentText;
                            bar.win.confirmUnsaved(function () {
                                bar.win.stopPlay(); bar.graph.edgeMode = false
                                var doLoad = function () {
                                    bar.win._applying = true; bar.graph.beginLoad(); bar.ctl.loadNamedSample(name); bar.graph.populate(); bar.win._applying = false;
                                    bar.graph.fitView(); if (bar.win.use3D) bar.graph3d.fit();
                                    bar.win.currentFile = ""; bar.win.docName = name; bar.win.markClean();
                                    bar.win.histReset();
                                };
                                if (bar.win.use3D) bar.win.beginPrepare3D(doLoad)
                                else doLoad()
                            });
                        }
                    }
                }

                // Data-set action buttons — all one size (uniform width + horizontal padding).
                ActionBtn {
                    text: "Load"
                    onClicked: bar.win.confirmUnsaved(function () { bar.dialogs.load(); })
                    ToolTip.visible: hovered
                    ToolTip.text: "Load a graph from JSON"
                }
                ActionBtn {
                    text: "Save"
                    onClicked: { if (bar.win.currentFile.length) { bar.win.syncViewConfig(); bar.ctl.saveToFile(bar.win.currentFile); bar.win.markClean(); } else bar.dialogs.openSave(false); }
                    ToolTip.visible: hovered
                    ToolTip.text: bar.win.currentFile.length ? ("Save to " + bar.win.baseName(bar.win.currentFile)) : "Save to a file…"
                }
                ActionBtn {
                    text: "Save As"
                    onClicked: bar.dialogs.openSave(true)
                    ToolTip.visible: hovered; ToolTip.text: "Save to a new file…"
                }
                ActionBtn {
                    text: "Clear"
                    onClicked: bar.win.confirmUnsaved(function () {
                        bar.win.stopPlay(); bar.graph.edgeMode = false;
                        bar.win._applying = true; bar.ctl.clear(); bar.win._applying = false;
                        bar.win.currentFile = ""; bar.win.docName = "untitled"; bar.win.markClean();
                    })
                    ToolTip.visible: hovered; ToolTip.text: "Clear the whole graph"
                }
                }   // end visualizer-only pickers
            }   // end midRow
        }       // end flexible middle clip region (fills the slack; no extra spacer)

        // Theme picker — replaces the old Light/Dark switch; scales to any number
        // of themes (see UiPalette.themeNames). Names shown capitalized.
        CategoryLabel { text: "Theme" }
        UiComboBox {
            id: themeBox
            Layout.preferredWidth: 110
            Layout.alignment: Qt.AlignVCenter
            model: bar.themeNames
            currentIndex: Math.max(0, bar.themeNames.indexOf(bar.themeName))
            font.capitalization: Font.Capitalize
            onActivated: bar.themeSelected(bar.themeNames[currentIndex])
            ToolTip.visible: hovered; ToolTip.text: "Application theme"
        }
        // Accent swatch — shows the effective accent; click to pick a custom one
        // (OS colour dialog), right-click to reset to the theme's preset. A ring
        // marks when a custom accent is active.
        Rectangle {
            id: accentSwatch
            Layout.preferredWidth: 22; Layout.preferredHeight: 22
            Layout.alignment: Qt.AlignVCenter
            radius: 4
            color: bar.accentColor
            border.width: bar.accentIsCustom ? 2 : 1
            border.color: bar.accentIsCustom
                          ? (_title_bar_defs.dark ? "#ffffff" : "#1e293b")
                          : (_title_bar_defs.dark ? "#ffffff55" : "#00000055")
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: function (m) {
                    if (m.button === Qt.RightButton) bar.accentResetRequested();
                    else bar.accentPickRequested();
                }
                ToolTip.visible: containsMouse
                ToolTip.text: "Accent colour — click to pick, right-click to reset"
            }
        }
        Item { Layout.preferredWidth: 12 }
        WinBtn { text: "—"; onClicked: bar.minimizeRequested() }
        WinBtn { text: bar.maximized ? "❐" : "☐"; onClicked: bar.maximizeToggled() }
        WinBtn { text: "✕"; hoverColor: "#e81123"; hoverTextColor: "white"; onClicked: bar.closeRequested() }
    }

    QtObject {
        id: _title_bar_defs
        // Follow the app theme. Each colour keeps its exact DARK value (the look the
        // user signed off on) and gains a LIGHT counterpart from the same slate ramp,
        // so the whole bar — surface, title, labels, version, separators, switch and
        // window buttons — flips with Theme.dark alongside the UiKit controls.
        readonly property bool dark: Theme.dark

        // background (+ a hairline under the bar, shown only in light to separate the
        // light chrome from the content below). Dark keeps its signed-off navy; light-
        // based themes follow Theme.panelBg so the bar tints with the theme (e.g. Breeze).
        readonly property color dark_background: dark ? "#1e293b" : Theme.panelBg
        readonly property color bar_bottom_border: dark ? "transparent" : "#e2e8f0"

        // theme switch text color
        readonly property color theme_switch_text_color: dark ? "#e2e8f0" : "#1e293b"

        // window buttons (min / max / close)
        readonly property color winbtn_text_color: dark ? "white" : "#1e293b"
        readonly property color winbtn_hover_color: dark ? "#334155" : "#e2e8f0"

        // app icon
        readonly property int icon_size: 24

        // vertical separator
        readonly property color separator_color: dark ? "#475569" : "#cbd5e1"

        // app title
        readonly property color title_color: dark ? "white" : "#0f172a"
        readonly property int title_font_pixel_size: 18
        readonly property bool title_bold: true

        // version
        readonly property color version_text_color: dark ? "#94a3b8" : "#64748b"
        readonly property real version_font_size: 15
        readonly property bool version_font_bold: true
        readonly property real version_label_width: 80

        // label
        readonly property color label_color: dark ? "#e2e8f0" : "#1e293b"
        readonly property int label_pixel_size: 15
        readonly property bool label_bold: true
        readonly property int label_wrap: Text.NoWrap

        // ActionBtn
        readonly property real actionBtn_preferred_width: 92
        readonly property int actionBtn_vcenter: Qt.AlignVCenter
        readonly property real actionBtn_left_padding: 16
        readonly property real actionBtn_right_padding: 16
    }
}
