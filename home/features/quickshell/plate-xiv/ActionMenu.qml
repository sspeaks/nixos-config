// ActionMenu — Plate XIV session / power / recording overlay
//
// IPC contract: target "actionMenu"
//   toggle()             — show or hide the menu
//   show()               — show unconditionally
//   hide()               — hide unconditionally
//   recordingStarted()   — called by plate-record-start after wf-recorder launches
//   recordingStopped()   — called by plate-record-stop after SIGINT completes
//
// Distinct from:
//   Launcher      — searchable DesktopEntries app picker (D22)
//   ControlCenter — polling status + system-control sliders (D23/D32)
//
// Layer-shell: Overlay, keyboard OnDemand, exclusiveZone 0, centered on the
// focused screen. Escape dismiss is handled by a focused child item rather than
// the PanelWindow itself (PanelWindow is Window-based, not Item-based).

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    visible: false

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    exclusiveZone: 0
    implicitWidth:  280
    implicitHeight: entryList.implicitHeight + Theme.spacingLg * 2
    color:          "transparent"

    // Tracks whether wf-recorder is running — updated via IPC by
    // plate-record-start and plate-record-stop on success.
    property bool recordingActive: false

    onVisibleChanged: {
        if (visible) {
            Qt.callLater(function() {
                if (root.visible) keyScope.forceActiveFocus();
            });
        }
    }

    // ── IPC ──────────────────────────────────────────────────────────────
    IpcHandler {
        target: "actionMenu"

        function toggle(): void {
            root.visible = !root.visible;
        }

        function show(): void {
            root.visible = true;
        }

        function hide(): void {
            root.visible = false;
        }

        function recordingStarted(): void {
            root.recordingActive = true;
        }

        function recordingStopped(): void {
            root.recordingActive = false;
        }
    }

    // ── Entries ───────────────────────────────────────────────────────────
    // Static JS array binding — no runtime JSON parsing or in-place mutation.
    // When recordingActive flips, QML reevaluates this binding to a fresh array,
    // which is enough for Repeater to rebuild the recording row.
    readonly property var entries: [
        {
            label:   root.recordingActive ? "Stop recording" : "Start recording",
            icon:    root.recordingActive ? "■" : "●",
            accent:  root.recordingActive,
            command: root.recordingActive ? ["plate-record-stop"] : ["plate-record-start"]
        },
        { label: "Lock",     icon: "⏹", accent: false, command: ["hyprlock"] },
        { label: "Logout",   icon: "←", accent: false, command: ["wlogout"]  },
        { label: "Shutdown", icon: "⏻", accent: false, command: ["plate-shutdown"] },
        { label: "Reboot",   icon: "↻", accent: false, command: ["plate-reboot"]  }
    ]

    FocusScope {
        id: keyScope
        anchors.fill: parent
        focus: root.visible

        Keys.onEscapePressed: function(event) {
            root.visible = false;
            event.accepted = true;
        }

        // ── Visual shell ──────────────────────────────────────────────────
        Rectangle {
            anchors.fill: parent
            color:        Theme.bgRaised
            border.width: Theme.border
            border.color: Theme.lineEdge

            ColumnLayout {
                id:           entryList
                anchors {
                    top:    parent.top
                    left:   parent.left
                    right:  parent.right
                    margins: Theme.spacingLg
                }
                spacing: 0

                // Header
                RowLayout {
                    Layout.fillWidth:    true
                    Layout.bottomMargin: Theme.spacingSm
                    spacing:             Theme.spacingSm

                    Text {
                        text:           "ACTIONS"
                        font.family:    Theme.fontUi
                        font.pointSize: 8
                        color:          Theme.fgMuted
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        visible:        root.recordingActive
                        color:          "transparent"
                        border.width:   Theme.border
                        border.color:   Theme.stateFail
                        implicitWidth:  recBadgeLabel.implicitWidth + Theme.spacingSm * 2
                        implicitHeight: recBadgeLabel.implicitHeight + Theme.spacingSm

                        Text {
                            id:               recBadgeLabel
                            anchors.centerIn: parent
                            text:             "⬤ REC"
                            font.family:      Theme.fontUi
                            font.pointSize:   8
                            color:            Theme.stateFail
                        }
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth:    true
                    implicitHeight:      Theme.border
                    color:               Theme.lineRule
                    Layout.bottomMargin: Theme.spacingSm
                }

                // Entry rows
                Repeater {
                    // Binding the model to root.entries is sufficient here:
                    // recordingActive produces a new array value, so the
                    // Repeater re-models without manual invalidation.
                    model: root.entries

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        implicitHeight:   rowContent.implicitHeight + Theme.spacingSm * 2
                        color:            rowHover.hovered
                                              ? Theme.accentPrimary
                                              : "transparent"
                        border.width:     0

                        RowLayout {
                            id: rowContent
                            anchors {
                                left:           parent.left
                                right:          parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin:     Theme.spacingSm
                                rightMargin:    Theme.spacingSm
                            }
                            spacing: Theme.spacingSm

                            Text {
                                text:           modelData.icon
                                font.family:    Theme.fontUi
                                font.pointSize: 10
                                color: modelData.accent
                                       ? Theme.stateFail
                                       : (rowHover.hovered
                                          ? Theme.bgRaised
                                          : Theme.accentPrimary)
                            }

                            Text {
                                Layout.fillWidth: true
                                text:             modelData.label
                                font.family:      Theme.fontUi
                                font.pointSize:   9
                                color:            rowHover.hovered ? Theme.bgRaised : Theme.fgPrimary
                            }
                        }

                        HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.visible = false;
                                Quickshell.execDetached(modelData.command);
                            }
                        }
                    }
                }
            }
        }
    }
}
