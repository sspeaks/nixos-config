// Top bar: reserves Theme.captionHeight logical pixels without taking focus.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    WlrLayershell.layer:         WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top:   true
        left:  true
        right: true
    }
    implicitHeight: Theme.captionHeight
    exclusiveZone:  Theme.captionHeight
    color:          Theme.bgBase

    // ── Root row ──────────────────────────────────────────────────────────
    RowLayout {
        anchors.fill:       parent
        anchors.leftMargin:  Theme.spacingSm
        anchors.rightMargin: Theme.spacingSm
        spacing: 0

        WorkspaceRibbon {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        // Unused alert slot.
        Item {
            id: anomalySlot
            implicitWidth:  Theme.spacingLg
            Layout.fillHeight: true
        }

        Clock {
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        }
    }

    // ── Bottom rule ───────────────────────────────────────────────────────
    Rectangle {
        anchors {
            bottom: parent.bottom
            left:   parent.left
            right:  parent.right
        }
        height: Theme.border
        color:  Theme.lineRule
    }
}
