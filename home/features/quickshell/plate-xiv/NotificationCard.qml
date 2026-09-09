// NotificationCard — single notification surface, Plate XIV chrome
//
// D9/D23 geometry: opaque bgRaised fill, 1px border, radius 0 — this is
// new chrome authored fresh under Plate XIV's zero-radius rule, so unlike
// dunst's unresolved corner_radius exception (D26/D29 #4) there is nothing
// to preserve here; sharp corners are simply correct from day one.
//
// Border color keys off urgency: Low -> lineRule (quietest), Normal ->
// lineEdge, Critical -> stateFail (D25 token — vermilion, no new hue).
//
// Auto-expiry: Notification.expireTimeout is informational only — the
// client (this file) is responsible for calling expire() once it elapses.
// expireTimeout < 0 means "no server-suggested timeout"; this card falls
// back to a fixed 8s so nothing lingers forever without becoming "sticky"
// on purpose (resident notifications are left alone).

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

Rectangle {
    id: root

    required property Notification notification

    readonly property int fallbackTimeoutMs: 8000

    function borderColorFor(urgency) {
        if (urgency === NotificationUrgency.Critical) return Theme.stateFail;
        if (urgency === NotificationUrgency.Low) return Theme.lineRule;
        return Theme.lineEdge;
    }

    implicitHeight: content.implicitHeight + Theme.spacingLg * 2
    color:          Theme.bgRaised
    border.width:   Theme.border
    border.color:   borderColorFor(notification.urgency)

    // Resident notifications (e.g. media controls) are meant to persist
    // until explicitly dismissed — only auto-expire non-resident ones.
    Timer {
        running: !root.notification.resident
        interval: root.notification.expireTimeout > 0
            ? root.notification.expireTimeout
            : root.fallbackTimeoutMs
        onTriggered: root.notification.expire()
    }

    ColumnLayout {
        id: content
        anchors {
            left:    parent.left
            right:   parent.right
            top:     parent.top
            margins: Theme.spacingLg
        }
        height:  implicitHeight
        spacing: Theme.spacingSm

        // ── Header: icon, app name, close ────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm

            IconImage {
                implicitSize: Theme.captionHeight - Theme.spacingSm * 2
                source: root.notification.appIcon
                    ? Quickshell.iconPath(root.notification.appIcon, true)
                    : ""
                visible: source !== ""
            }

            Text {
                Layout.fillWidth: true
                text:           root.notification.appName
                font.family:    Theme.fontUi
                font.pointSize: 9
                color:          Theme.fgSecondary
                elide:          Text.ElideRight
            }

            // Dismiss — explicit, no ambiguity about swipe/timeout gestures.
            Text {
                text:           "×"
                font.family:    Theme.fontUi
                font.pointSize: 11
                color:          Theme.fgMuted

                MouseArea {
                    anchors.fill:    parent
                    anchors.margins: -Theme.spacingSm
                    cursorShape:     Qt.PointingHandCursor
                    onClicked:       root.notification.dismiss()
                }
            }
        }

        // ── Summary ───────────────────────────────────────────────────────
        Text {
            Layout.fillWidth: true
            text:           root.notification.summary
            font.family:    Theme.fontUi
            font.pointSize: 10
            color:          Theme.fgPrimary
            wrapMode:       Text.Wrap
        }

        // ── Body ──────────────────────────────────────────────────────────
        Text {
            Layout.fillWidth: true
            visible:        text !== ""
            text:           root.notification.body
            textFormat:     Text.StyledText
            font.family:    Theme.fontUi
            font.pointSize: 9
            color:          Theme.fgSecondary
            wrapMode:       Text.Wrap
        }

        // ── Actions ───────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            visible: root.notification.actions.length > 0
            spacing: Theme.spacingSm

            Repeater {
                model: root.notification.actions

                delegate: Rectangle {
                    id: actionChip
                    required property NotificationAction modelData

                    implicitWidth:  actionLabel.implicitWidth + Theme.spacingLg * 2
                    implicitHeight: actionLabel.implicitHeight + Theme.spacingSm * 2
                    color:          Theme.bgFill
                    border.width:   Theme.border
                    border.color:   Theme.lineEdge

                    Text {
                        id: actionLabel
                        anchors.centerIn: parent
                        text:             actionChip.modelData.text
                        font.family:      Theme.fontUi
                        font.pointSize:   9
                        color:            Theme.fgPrimary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    actionChip.modelData.invoke()
                    }
                }
            }
        }
    }
}
