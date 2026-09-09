// OSD — Plate XIV volume / brightness overlay
//
// IPC contract: target "osd", functions showVolume() and
// showBrightness(). Each call polls the matching Plate helper and
// refreshes this small centred overlay.
//
// Layer-shell contract: layer Overlay, no anchors, exclusiveZone 0,
// keyboardFocus None — like Launcher, this floats on the compositor's
// default/focused screen without reserving space.

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
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    exclusiveZone: 0
    implicitWidth: 300
    implicitHeight: 100
    color: "transparent"

    property string iconText:      "🔊"
    property string labelText:     "VOLUME"
    property string valueText:     "0%"
    property real   progressValue: 0

    function setDisplay(icon, label, value, progress): void {
        root.iconText = icon;
        root.labelText = label;
        root.valueText = value;
        root.progressValue = Math.max(0, Math.min(1, progress));
        root.visible = true;
        hideTimer.restart();
    }

    // ── IPC ───────────────────────────────────────────────────────────────
    IpcHandler {
        target: "osd"

        function showVolume(): void {
            root.iconText = "🔊";
            root.labelText = "VOLUME";
            root.valueText = "...";
            root.progressValue = 0;
            root.visible = true;
            hideTimer.restart();

            volumeReadProc.running = false;
            Qt.callLater(function() { volumeReadProc.running = true; });
        }

        function showBrightness(): void {
            root.iconText = "☀";
            root.labelText = "BRIGHTNESS";
            root.valueText = "...";
            root.progressValue = 0;
            root.visible = true;
            hideTimer.restart();

            brightnessReadProc.running = false;
            Qt.callLater(function() { brightnessReadProc.running = true; });
        }
    }

    Timer {
        id:       hideTimer
        interval: 1500
        repeat:   false
        onTriggered: root.visible = false
    }

    // ── Backend reads ─────────────────────────────────────────────────────
    // `plate-volume-get` → "VOLUME MUTED" e.g. "0.72 0" or "0.50 1"
    Process {
        id:      volumeReadProc
        command: ["plate-volume-get"]
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                const parts = line.trim().split(/\s+/);
                if (parts.length < 2) return;

                const volume = parseFloat(parts[0]);
                const muted = parts[1] === "1";
                if (isNaN(volume)) return;

                const clamped = Math.max(0, Math.min(1, volume));
                if (muted) {
                    root.setDisplay("🔊", "VOLUME", "MUTED", 0);
                    return;
                }

                const pct = Math.round(clamped * 100);
                root.setDisplay("🔊", "VOLUME", pct + "%", clamped);
            }
        }
    }

    // `plate-brightness-get` → "CURRENT MAX" e.g. "420 800"
    Process {
        id:      brightnessReadProc
        command: ["plate-brightness-get"]
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                const parts = line.trim().split(/\s+/);
                if (parts.length < 2) return;

                const current = parseInt(parts[0], 10);
                const maximum = parseInt(parts[1], 10);
                if (isNaN(current) || isNaN(maximum) || maximum <= 0) return;

                const pct = Math.max(0, Math.min(100, Math.round(current / maximum * 100)));
                root.setDisplay("☀", "BRIGHTNESS", pct + "%", pct / 100);
            }
        }
    }

    // ── Visual shell ──────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color:        Theme.bgRaised
        border.width: Theme.border
        border.color: Theme.lineEdge

        ColumnLayout {
            width: parent.width - Theme.spacingLg * 2
            anchors.centerIn: parent
            spacing: Theme.spacingSm

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSm

                Text {
                    text:           root.iconText
                    font.family:    Theme.fontUi
                    font.pointSize: 16
                    color:          Theme.accentPrimary
                }

                Text {
                    Layout.fillWidth: true
                    text:           root.labelText
                    font.family:    Theme.fontUi
                    font.pointSize: 9
                    color:          Theme.fgMuted
                }

                Text {
                    text:           root.valueText
                    font.family:    Theme.fontMono
                    font.pointSize: 12
                    color:          Theme.fgPrimary
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight:   10
                color:            Theme.bgFill
                border.width:     Theme.border
                border.color:     Theme.lineEdge

                Rectangle {
                    width:  parent.width * root.progressValue
                    height: parent.height
                    color:  Theme.accentPrimary
                }
            }
        }
    }
}
