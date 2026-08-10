// NotificationHost — Plate XIV notification stack
//
// D23: Quickshell-native notification surface for the niri session. dunst
// stays wired for Hyprland (D26 re-themes it in this same batch) — this
// file does not replace dunst, it coexists with it per-session. Review
// follow-up: dunst's own systemd unit is now gated (see dunst/default.nix,
// `ConditionEnvironment=!NIRI_SOCKET`) so it never starts alongside this
// host under niri — no more duplicate-daemon race for
// org.freedesktop.Notifications there.
//
// D9 layer-shell contract: layer Top (deliberately NOT Overlay, so a
// fullscreen client still wins), anchors Top|Right, exclusiveZone 0,
// keyboardFocus None — notifications never steal focus, full stop.
// Positioned below the 28px caption per D23: top margin =
// Theme.captionHeight + Theme.spacingLg, plus `reserveTop` (see below).
//
// Overlap fix (review follow-up): ControlCenter anchors the exact same
// Top|Right corner. Rather than relying on layer-shell stacking order
// (compositor-controlled, not a contract Quickshell exposes or guarantees
// per-layer), shell.qml binds `reserveTop` to ControlCenter's live
// implicitHeight whenever it's open, so this stack deterministically
// relocates below ControlCenter instead of overlapping it — this
// guarantees every notification, including critical ones, stays fully
// visible regardless of whether ControlCenter is open.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

PanelWindow {
    id: root

    // Set from shell.qml: ControlCenter's implicitHeight + a gap when it is
    // visible, 0 otherwise. Defaults to 0 so this file stays independently
    // usable/testable without ControlCenter present.
    property real reserveTop: 0

    WlrLayershell.layer:         WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top:   true
        right: true
    }
    margins {
        top:   Theme.captionHeight + Theme.spacingLg + reserveTop
        right: Theme.spacingLg
    }
    exclusiveZone:  0
    color:          "transparent"
    implicitWidth:  320
    implicitHeight: column.implicitHeight

    NotificationServer {
        id: server

        // Survive shell hot-reload — a crash/reload must not drop a
        // notification the user hasn't seen yet.
        keepOnReload:            true
        persistenceSupported:    false
        bodySupported:           true
        bodyMarkupSupported:     true
        bodyHyperlinksSupported: false
        bodyImagesSupported:     false
        actionsSupported:        true
        actionIconsSupported:    false
        imageSupported:          false
        inlineReplySupported:    false

        // This IS the notification host — every incoming notification is
        // tracked (rendered) rather than silently dropped.
        onNotification: notification => {
            notification.tracked = true;
        }
    }

    ColumnLayout {
        id: column
        width:   parent.width
        height:  implicitHeight
        spacing: Theme.spacingSm

        Repeater {
            model: server.trackedNotifications

            delegate: NotificationCard {
                required property Notification modelData
                Layout.fillWidth: true
                notification: modelData
            }
        }
    }
}
