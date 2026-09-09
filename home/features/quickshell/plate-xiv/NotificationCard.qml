// Notification card. expireTimeout is informational: this component must
// call expire(). Non-resident notifications use an 8 s fallback when the
// supplied timeout is non-positive; resident notifications persist.

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
