// Caption — Plate XIV top bar
//
// Geometry:  top edge, 28 px exclusive zone, full-width
// Surface:   opaque bgBase fill, 1 px lineRule bottom border, radius 0
// Left:      WorkspaceRibbon (workspace list + focused window title)
// Centre:    anomaly slot — empty when healthy, reserved for future alerts
// Right:     Clock (HH  MM tabular display)
//
// No tray, icons, or permanent telemetry.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    // D9: Top layer, Top|Left|Right anchors, exclusiveZone 28, margins 0, keyboardFocus None.
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

        // Left: workspaces + focused title
        WorkspaceRibbon {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        // Centre: anomaly slot — empty when healthy
        Item {
            id: anomalySlot
            implicitWidth:  Theme.spacingLg
            Layout.fillHeight: true
            // Future: bind to a notification/alert model and surface here
        }

        // Right: clock
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
