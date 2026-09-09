// Notification stack for niri. dunst/default.nix excludes dunst from niri
// to avoid competing for org.freedesktop.Notifications.
// Use Top, not Overlay, so fullscreen clients take precedence; never grab focus.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

PanelWindow {
    id: root

    // shell.qml supplies ControlCenter's height plus a gap while it is visible.
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

        // Preserve tracked notifications across shell hot-reload.
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

        // Incoming notifications must be tracked to appear in the model.
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
