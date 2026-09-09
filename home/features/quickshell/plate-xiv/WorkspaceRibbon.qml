// Workspace list via ext-workspace-v1; focused title via
// wlr-foreign-toplevel-management. Unavailable protocols leave sections empty.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.WindowManager

Item {
    id: root

    implicitHeight: Theme.captionHeight

    // ── Focused window title ───────────────────────────────────────────────
    // ToplevelManager.activeToplevel is null when no window is focused.
    readonly property string focusedTitle:
        ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.title : ""

    RowLayout {
        anchors.fill: parent
        spacing: Theme.spacingSm

        // ── Workspace ribbon ───────────────────────────────────────────────
        Repeater {
            model: ScriptModel {
                values: {
                    const ws = [...WindowManager.windowsets].filter(w => w.shouldDisplay)
                    ws.sort((a, b) => {
                        const ca = a.coordinates[0] ?? 0
                        const cb = b.coordinates[0] ?? 0
                        return ca - cb
                    })
                    return ws
                }
            }

            delegate: Item {
                id: wsChip
                required property Windowset modelData

                implicitWidth:  wsLabel.implicitWidth + Theme.spacingSm * 2
                implicitHeight: root.implicitHeight
                Layout.fillHeight: true

                Rectangle {
                    anchors {
                        bottom: parent.bottom
                        left:   parent.left
                        right:  parent.right
                    }
                    height:  Theme.border * 2
                    color:   wsChip.modelData.active ? Theme.accentPrimary : "transparent"
                }

                Text {
                    id: wsLabel
                    anchors.centerIn: parent
                    text: wsChip.modelData.name || (wsChip.modelData.coordinates[0] + 1).toString()
                    font.family:    Theme.fontUi
                    font.pointSize: 9
                    color: wsChip.modelData.active ? Theme.fgPrimary : Theme.fgMuted
                }
            }
        }

        // ── Focused title ──────────────────────────────────────────────────
        Text {
            id: titleText
            Layout.fillWidth:    true
            Layout.fillHeight:   true
            Layout.leftMargin:   Theme.spacingSm
            verticalAlignment:   Text.AlignVCenter
            elide:               Text.ElideRight
            text:                root.focusedTitle
            font.family:         Theme.fontUi
            font.pointSize:      9
            color:               Theme.fgSecondary
        }
    }
}
