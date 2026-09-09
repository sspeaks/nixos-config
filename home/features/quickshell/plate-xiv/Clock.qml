// Caption clock; minute precision avoids unnecessary repaints.

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

        // Iosevka Nerd Font has tabular figures by default.
        Text {
            text:           clock.hours.toString().padStart(2, "0")
            font.family:    Theme.fontMono
            font.pointSize: 9
            color:          Theme.fgPrimary
        }

        Text {
            text:           "  "
            font.family:    Theme.fontMono
            font.pointSize: 9
            color:          Theme.fgMuted
        }

        Text {
            text:           clock.minutes.toString().padStart(2, "0")
            font.family:    Theme.fontMono
            font.pointSize: 9
            color:          Theme.fgPrimary
        }
    }
}
