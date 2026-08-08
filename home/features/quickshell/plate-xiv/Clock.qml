// Clock — right section of Caption
//
// Tabular HH  MM display with a dim colon separator.
// Updates at minute precision to avoid unnecessary repaints.
// Uses SystemClock from Quickshell core — no external dependencies.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    implicitWidth:  clockRow.implicitWidth + Theme.spacingSm * 2
    implicitHeight: Theme.captionHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    RowLayout {
        id: clockRow
        anchors.centerIn: parent
        spacing: 0

        // Hours — zero-padded; Iosevka Nerd Font has tabular figures by default
        Text {
            text:           clock.hours.toString().padStart(2, "0")
            font.family:    Theme.fontMono
            font.pointSize: 9
            color:          Theme.fgPrimary
        }

        // Colon separator — subdued gap between HH and MM
        Text {
            text:           "  "
            font.family:    Theme.fontMono
            font.pointSize: 9
            color:          Theme.fgMuted
        }

        // Minutes — zero-padded
        Text {
            text:           clock.minutes.toString().padStart(2, "0")
            font.family:    Theme.fontMono
            font.pointSize: 9
            color:          Theme.fgPrimary
        }
    }
}
