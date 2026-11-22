pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import GraphVis
import UiKit

// All of the app's dialogs (colour picker, document save/load, the unsaved-changes
// prompt, and the paste-edge-list popup), kept out of Main.qml. The window drives
// them through the functions below and supplies itself, the controller and both
// graph views so handlers don't reach across files for ids.
Item {
    id: dlgs
    required property var win
    required property var ctl
    required property var graph
    required property var graph3d

    // ---- colour picker (shared by the 2D/3D Colours controls) ----
    property string _colorRole: ""
    function openColor(role, current) { dlgs._colorRole = role; colorDialog.selectedColor = current; colorDialog.open(); }
    ColorDialog {
        id: colorDialog
        title: "Choose colour"
        onAccepted: {
            if (dlgs.win.use3D) dlgs.graph3d.applyColor(dlgs._colorRole, selectedColor);
            else dlgs.graph.applyColor(dlgs._colorRole, selectedColor);
        }
    }

    // ---- accent picker (the app theme's accent colour) ----
    function openAccent(current) { accentDialog.selectedColor = current; accentDialog.open(); }
    ColorDialog {
        id: accentDialog
        title: "Choose accent colour"
        onAccepted: dlgs.win.userAccent = selectedColor
    }

    // ---- document save / load (full JSON) ----
    // Save As prompt; pass prefill=true to default to the current file name.
    function openSave(prefill) {
        if (prefill && dlgs.win.currentFile.length) saveDialog.selectedFile = dlgs.win.currentFile;
        saveDialog.open();
    }
    function load() { loadDialog.open(); }
    function openUnsaved() { unsavedDialog.open(); }
    function openPaste() { pasteDialog.open(); }

    FileDialog {
        id: saveDialog
        title: "Save graph as JSON"
        fileMode: FileDialog.SaveFile
        nameFilters: ["Graph JSON (*.json)", "All files (*)"]
        defaultSuffix: "json"
        onAccepted: {
            dlgs.win.syncViewConfig();
            dlgs.ctl.saveToFile(selectedFile); dlgs.win.currentFile = "" + selectedFile; dlgs.win.docName = dlgs.win.baseName(selectedFile);
            dlgs.win.addRecent(selectedFile);
            if (dlgs.win._savePending) dlgs.win._finishSave(); else dlgs.win.markClean();
        }
        // Cancelling a Save-As that was part of an unsaved-changes guard aborts the
        // whole guarded action.
        onRejected: if (dlgs.win._savePending) dlgs.win._guardCancel()
    }
    // Save / Discard / Cancel prompt for unsaved graph edits (see win.confirmUnsaved).
    Dialog {
        id: unsavedDialog
        modal: true
        title: "Unsaved changes"
        anchors.centerIn: Overlay.overlay
        standardButtons: Dialog.Save | Dialog.Discard | Dialog.Cancel
        // Fixed-width wrapper (an Item's implicitWidth is writable, unlike a
        // Label's) so WordWrap doesn't loop against the Dialog's implicitWidth.
        Item {
            implicitWidth: 360
            implicitHeight: unsavedMsg.implicitHeight
            Label {
                id: unsavedMsg
                anchors { left: parent.left; right: parent.right }
                text: "“" + (dlgs.win.docName.length ? dlgs.win.docName : "Untitled") + "” has unsaved changes.\nSave them before continuing?"
                color: Theme.textPrimary; wrapMode: Text.WordWrap
            }
        }
        onAccepted: dlgs.win._guardSave()       // Save
        onDiscarded: dlgs.win._guardDiscard()   // Discard
        onRejected: dlgs.win._guardCancel()     // Cancel / Esc
    }
    FileDialog {
        id: loadDialog
        title: "Load graph from JSON"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Graph JSON (*.json)", "All files (*)"]
        onAccepted: {
            // The unsaved-changes guard already ran (on the Load button click), so
            // this dialog only opens once the current graph is saved or discarded —
            // we just load the chosen file here.
            var f = selectedFile;
            dlgs.win.stopPlay(); dlgs.graph.edgeMode = false;
            dlgs.win.currentFile = "" + f; dlgs.win.docName = dlgs.win.baseName(f);
            dlgs.win.addRecent(f);
            dlgs.ctl.loadFromFileAsync(f);     // off-thread; fitView on completion
        }
    }

    Popup {
        id: pasteDialog
        modal: true
        focus: true                      // let the popup (and its TextArea) receive the keyboard
        popupType: Popup.Item
        width: 470; height: 360
        padding: 16
        // Centred by binding; dragging the title bar overrides x/y, and each
        // re-open re-centres it.
        x: Overlay.overlay ? Math.round((Overlay.overlay.width - width) / 2) : 0
        y: Overlay.overlay ? Math.round((Overlay.overlay.height - height) / 2) : 0
        background: Rectangle { color: Theme.panelBg; border.color: Theme.panelBorder; radius: 10 }
        onOpened: {
            if (Overlay.overlay) { x = Math.round((Overlay.overlay.width - width) / 2);
                                   y = Math.round((Overlay.overlay.height - height) / 2); }
            pasteArea.forceActiveFocus();
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 10
            Label {
                text: "Paste edge list   ⠿"; font.bold: true; font.pixelSize: 15; color: Theme.textPrimary
                Layout.fillWidth: true
                MouseArea {                         // drag the title bar to move the dialog
                    anchors.fill: parent
                    cursorShape: Qt.SizeAllCursor
                    property real ox: 0; property real oy: 0
                    onPressed: function (m) {
                        var g = mapToItem(Overlay.overlay, m.x, m.y);
                        ox = g.x - pasteDialog.x; oy = g.y - pasteDialog.y;
                    }
                    onPositionChanged: function (m) {
                        if (!pressed) return;
                        var g = mapToItem(Overlay.overlay, m.x, m.y);
                        pasteDialog.x = g.x - ox; pasteDialog.y = g.y - oy;
                    }
                }
            }
            Label {
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                text: "One edge per line:  from  to  [weight]   (whitespace or comma separated). "
                      + "A single name adds an isolated vertex. '#' starts a comment."
                color: Theme.textMuted; font.pixelSize: 11
            }
            ScrollView {
                Layout.fillWidth: true; Layout.fillHeight: true
                TextArea {
                    id: pasteArea
                    placeholderText: "A B 7\nA C 9\nB C 10\nC D 2\nD E"
                    font.family: "monospace"; font.pixelSize: 13
                    selectByMouse: true; wrapMode: TextArea.NoWrap
                    background: Rectangle { color: Theme.canvasBg; border.color: Theme.panelBorder; radius: 4 }
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                CheckBox { id: pasteDirected; text: "Directed"; checked: dlgs.ctl.directed }
                Item { Layout.fillWidth: true }
                UiButton { text: "Cancel"; onClicked: pasteDialog.close() }
                UiButton {
                    text: "Append"
                    enabled: pasteArea.text.trim().length > 0
                    onClicked: { dlgs.graph.beginLoad(); dlgs.ctl.loadEdgeList(pasteArea.text, pasteDirected.checked, false); dlgs.graph.populate(); dlgs.graph.fitView(); pasteDialog.close(); }
                }
                UiButton {
                    text: "Replace"; highlighted: true
                    enabled: pasteArea.text.trim().length > 0
                    onClicked: dlgs.win.confirmUnsaved(function () {
                        dlgs.win.stopPlay(); dlgs.graph.edgeMode = false;
                        dlgs.win._applying = true; dlgs.graph.beginLoad(); dlgs.ctl.loadEdgeList(pasteArea.text, pasteDirected.checked, true); dlgs.graph.populate(); dlgs.win._applying = false;
                        dlgs.graph.fitView(); if (dlgs.win.use3D) dlgs.graph3d.fit();
                        dlgs.win.currentFile = ""; dlgs.win.docName = "pasted"; dlgs.win.modified = true;   // pasted data is unsaved
                        dlgs.win.histReset();
                        pasteDialog.close();
                    })
                }
            }
        }
    }
}
