// Plate XIV status and system controls. IPC: controlCenter.toggle().
// Pointer-driven controls leave the keyboard grab to the launcher.
//
// Battery state comes from UPower; packages/plate-controls owns the other
// backends and their stdout/error contracts. Status helpers poll every 3 s
// while visible; hiding cancels reads, not in-flight mutations.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower

PanelWindow {
    id: root

    visible: false

    WlrLayershell.layer:         WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top:   true
        right: true
    }
    margins {
        top:   Theme.captionHeight + Theme.spacingLg
        right: Theme.spacingLg
    }
    exclusiveZone:  0
    implicitWidth:  260
    implicitHeight: panel.implicitHeight
    color:          "transparent"

    // ── Brightness state ─────────────────────────────────────────────────
    property int  brightnessPct:   -1     // -1 = loading
    property bool brightnessAvail: true   // false once command exits non-0
    property int  brightnessWritePending: -1
    property bool brightnessActionFailed: false

    // ── Volume state ──────────────────────────────────────────────────────
    property real volumeLevel:   -1       // -1 = loading; 0.0–1.0 when loaded
    property bool volumeMuted:   false
    property bool volumeAvail:   true     // false once command exits non-0
    property real volumeWritePending: -1
    property bool volumeActionFailed: false

    // ── Wi-Fi state ───────────────────────────────────────────────────────
    property bool   wifiPowered: false
    property string wifiState:   ""
    property string wifiNetwork: ""
    property bool   wifiAvail:   false
    property bool   wifiStatusFailed: false
    property bool   wifiActionFailed: false

    // ── Bluetooth state ───────────────────────────────────────────────────
    property bool btPowered: false
    property bool btAvail:   false
    property bool btFailed:  false
    property bool btRepollPending: false

    function pollWifi(): void {
        if (!wifiStatusProc.running) {
            wifiStatusProc.parsed = false;
            wifiStatusProc.running = true;
        }
    }

    function pollBluetooth(): void {
        if (!root.visible) return;
        if (!btStatusProc.running) {
            btStatusProc.parsed = false;
            btStatusProc.running = true;
        }
    }

    function requestBrightnessWrite(pct: int): void {
        brightnessWritePending = pct;
        flushBrightnessWrite();
    }

    function flushBrightnessWrite(): void {
        if (brightnessSetProc.running || brightnessWritePending < 0) return;

        const pct = brightnessWritePending;
        brightnessWritePending = -1;
        brightnessActionFailed = false;
        brightnessSetProc.command = ["plate-brightness-set", String(pct)];
        brightnessSetProc.running = true;
    }

    function requestVolumeWrite(level: real): void {
        volumeWritePending = level;
        flushVolumeWrite();
    }

    function flushVolumeWrite(): void {
        if (volumeSetProc.running || volumeWritePending < 0) return;

        const level = volumeWritePending;
        volumeWritePending = -1;
        volumeActionFailed = false;
        volumeSetProc.command = ["plate-volume-set", level.toFixed(2)];
        volumeSetProc.running = true;
    }

    // ── Poll timer ────────────────────────────────────────────────────────
    Timer {
        id:       pollTimer
        interval: 3000
        repeat:   true
        running:  false
        onTriggered: {
            if (!brightnessGetProc.running
                    && !brightnessSetProc.running
                    && root.brightnessWritePending < 0)
                brightnessGetProc.running = true;
            if (!volumeReadProc.running
                    && !volumeSetProc.running
                    && root.volumeWritePending < 0)
                volumeReadProc.running = true;
            root.pollWifi();
            root.pollBluetooth();
        }
    }

    onVisibleChanged: {
        if (visible) {
            // Immediate first poll, then let the timer take over.
            brightnessGetProc.running = true;
            volumeReadProc.running    = true;
            root.pollWifi();
            root.pollBluetooth();
            pollTimer.start();
        } else {
            pollTimer.stop();
            // Stop reads without interrupting mutations.
            brightnessGetProc.running = false;
            volumeReadProc.running    = false;
            wifiStatusProc.running    = false;
            btStatusProc.running      = false;
        }
    }

    // ── Brightness processes ──────────────────────────────────────────────
    Process {
        id:      brightnessGetProc
        command: ["plate-brightness-get"]
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                const parts = line.trim().split(/\s+/);
                if (parts.length >= 2) {
                    const cur = parseInt(parts[0], 10);
                    const max = parseInt(parts[1], 10);
                    if (!isNaN(cur) && !isNaN(max) && max > 0) {
                        root.brightnessPct   = Math.round(cur / max * 100);
                        root.brightnessAvail = true;
                    }
                }
            }
        }
        onExited: function(code, _status) {
            if (code !== 0) root.brightnessAvail = false;
        }
    }

    // Writes are serialized. Slider movement coalesces to one pending value while
    // the helper runs, then starts the latest request only after it exits.
    Process {
        id:      brightnessSetProc
        running: false
        onExited: function(code, _status) {
            brightnessSetProc.running = false;
            root.brightnessActionFailed = code !== 0;
            Qt.callLater(function() {
                if (root.brightnessWritePending >= 0) {
                    root.flushBrightnessWrite();
                } else if (root.visible && !brightnessGetProc.running) {
                    brightnessGetProc.running = true;
                }
            });
        }
    }

    // ── Volume processes ──────────────────────────────────────────────────
    Process {
        id:      volumeReadProc
        command: ["plate-volume-get"]
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                const parts = line.trim().split(/\s+/);
                if (parts.length >= 2) {
                    const vol   = parseFloat(parts[0]);
                    const muted = (parts[1] === "1");
                    if (!isNaN(vol)) {
                        root.volumeLevel = vol;
                        root.volumeMuted = muted;
                        root.volumeAvail = true;
                    }
                }
            }
        }
        onExited: function(code, _status) {
            if (code !== 0) root.volumeAvail = false;
        }
    }

    // As with brightness, retain only the newest request while a write is active.
    Process {
        id:      volumeSetProc
        running: false
        onExited: function(code, _status) {
            volumeSetProc.running = false;
            root.volumeActionFailed = code !== 0;
            Qt.callLater(function() {
                if (root.volumeWritePending >= 0) {
                    root.flushVolumeWrite();
                } else if (root.visible && !volumeReadProc.running) {
                    volumeReadProc.running = true;
                }
            });
        }
    }

    // Re-reads volume after toggle so mute indicator updates immediately.
    Process {
        id:      volumeMuteProc
        command: ["plate-volume-toggle-mute"]
        running: false
        onExited: function(code, _status) {
            root.volumeActionFailed = code !== 0;
            if (root.visible && !volumeReadProc.running) volumeReadProc.running = true;
        }
    }

    // ── Wi-Fi processes ───────────────────────────────────────────────────
    // Radio power and connection state are independent; preserve spaces in SSIDs.
    Process {
        id:      wifiStatusProc
        command: ["plate-wifi-status"]
        running: false
        property bool parsed: false
        stdout: SplitParser {
            onRead: function(line) {
                const match = line.match(/^\s*(\S+)\s+(\S+)(?:\s+(.*?))?\s*$/);
                if (!match) return;

                const poweredToken = match[1].toLowerCase();
                const powered = poweredToken === "1"
                             || poweredToken === "on"
                             || poweredToken === "true"
                             || poweredToken === "yes";
                const unpowered = poweredToken === "0"
                               || poweredToken === "off"
                               || poweredToken === "false"
                               || poweredToken === "no";
                if (!powered && !unpowered) return;

                wifiStatusProc.parsed = true;
                root.wifiPowered = powered;
                root.wifiState   = match[2].toLowerCase();
                root.wifiNetwork = match[3] || "";
                root.wifiAvail   = true;
                root.wifiStatusFailed = false;
            }
        }
        onExited: function(code, _status) {
            if (code !== 0 || !parsed) {
                root.wifiAvail  = false;
                root.wifiStatusFailed = true;
            }
        }
    }

    Process {
        id:      wifiToggleProc
        command: ["plate-wifi-toggle"]
        running: false
        onExited: function(code, _status) {
            root.wifiActionFailed = code !== 0;
            if (root.visible) root.pollWifi();
        }
    }

    Process {
        id:      wifiConfigureProc
        command: ["plate-wifi-configure"]
        running: false
        onExited: function(code, _status) {
            root.wifiActionFailed = code !== 0;
            if (root.visible) root.pollWifi();
        }
    }

    // ── Bluetooth processes ───────────────────────────────────────────────
    Process {
        id:      btStatusProc
        command: ["plate-bluetooth-status"]
        running: false
        property bool parsed: false
        stdout: SplitParser {
            onRead: function(line) {
                const parts = line.trim().split(/\s+/);
                if (parts.length >= 2
                        && (parts[0] === "0" || parts[0] === "1")
                        && /^\d+$/.test(parts[1])) {
                    btStatusProc.parsed = true;
                    root.btPowered = (parts[0] === "1");
                    root.btAvail   = true;
                }
            }
        }
        onExited: function(code, _status) {
            if (code !== 0 || !parsed) root.btAvail = false;
            if (root.visible && root.btRepollPending && !btToggleProc.running) {
                root.btRepollPending = false;
                Qt.callLater(function() { root.pollBluetooth(); });
            }
        }
    }

    // Re-poll after success or failure rather than assuming the radio changed.
    Process {
        id:      btToggleProc
        command: ["plate-bluetooth-toggle"]
        running: false
        onExited: function(code, _status) {
            root.btFailed = code !== 0;
            Qt.callLater(function() {
                if (root.visible) {
                    if (btStatusProc.running) {
                        root.btRepollPending = true;
                    } else {
                        root.pollBluetooth();
                    }
                }
            });
        }
    }

    // ── IPC ───────────────────────────────────────────────────────────────
    IpcHandler {
        target: "controlCenter"

        function toggle(): void {
            root.visible = !root.visible;
        }
    }

    SystemClock {
        id:        clock
        precision: SystemClock.Seconds
    }

    Rectangle {
        id: panel
        width:          parent.width
        implicitHeight: column.implicitHeight + Theme.spacingLg * 2
        color:          Theme.bgRaised
        border.width:   Theme.border
        border.color:   Theme.lineEdge

        ColumnLayout {
            id: column
            anchors {
                left:    parent.left
                right:   parent.right
                top:     parent.top
                margins: Theme.spacingLg
            }
            height:  implicitHeight
            spacing: Theme.spacingSm

            // ── Header ────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text:           "CONTROL"
                    font.family:    Theme.fontUi
                    font.pointSize: 9
                    color:          Theme.fgMuted
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
                        onClicked:       root.visible = false
                    }
                }
            }

            // ── Clock / date ──────────────────────────────────────────────
            Text {
                Layout.fillWidth: true
                text: clock.hours.toString().padStart(2, "0") + ":"
                    + clock.minutes.toString().padStart(2, "0") + ":"
                    + clock.seconds.toString().padStart(2, "0")
                font.family:    Theme.fontMono
                font.pointSize: 18
                color:          Theme.fgPrimary
            }

            Text {
                Layout.fillWidth: true
                text:           Qt.formatDate(clock.date, "dddd, MMMM d")
                font.family:    Theme.fontUi
                font.pointSize: 9
                color:          Theme.fgSecondary
            }

            // ── Divider ───────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight:   Theme.border
                color:            Theme.lineRule
            }

            // ── Battery row (UPower; hidden on systems without a battery) ─
            // percentage is 0.0–1.0 per Quickshell UPower binding.
            RowLayout {
                Layout.fillWidth: true
                implicitHeight:   Theme.captionHeight
                spacing:          Theme.spacingSm
                visible:          UPower.displayDevice !== null
                                  && UPower.displayDevice.isPresent

                Text {
                    text:           "BATT"
                    font.family:    Theme.fontUi
                    font.pointSize: 8
                    color:          Theme.fgMuted
                    Layout.preferredWidth: 30
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight:   4
                    color:            Theme.bgFill
                    border.width:     Theme.border
                    border.color:     Theme.lineEdge

                    Rectangle {
                        width:  parent.width
                            * (UPower.displayDevice
                               ? UPower.displayDevice.percentage : 0)
                        height: parent.height
                        color:  Theme.fgPrimary
                    }
                }

                Text {
                    text: UPower.displayDevice
                        ? Math.round(UPower.displayDevice.percentage * 100) + "%"
                        : "--"
                    font.family:    Theme.fontMono
                    font.pointSize: 8
                    color:          Theme.fgPrimary
                    Layout.preferredWidth: 36
                    horizontalAlignment:   Text.AlignRight
                }
            }

            // ── Brightness row ────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                implicitHeight:   Theme.captionHeight
                spacing:          Theme.spacingSm
                visible:          root.brightnessAvail

                Text {
                    text:           "BRGHT"
                    font.family:    Theme.fontUi
                    font.pointSize: 8
                    color:          Theme.fgMuted
                    Layout.preferredWidth: 30
                }

                Text {
                    visible:        root.brightnessPct < 0
                    text:           "--"
                    font.family:    Theme.fontMono
                    font.pointSize: 8
                    color:          Theme.fgMuted
                    Layout.fillWidth: true
                }

                Slider {
                    id:               brightnessSlider
                    Layout.fillWidth: true
                    visible:          root.brightnessPct >= 0
                    from:  0;  to: 100;  stepSize: 1
                    value: root.brightnessPct >= 0 ? root.brightnessPct : 0
                    onMoved: {
                        const pct = Math.round(brightnessSlider.value);
                        root.brightnessPct = pct;  // optimistic update
                        root.requestBrightnessWrite(pct);
                    }
                }

                Text {
                    visible:        root.brightnessPct >= 0
                    text: root.brightnessActionFailed
                          ? "ACTION FAILED" : root.brightnessPct + "%"
                    font.family:    Theme.fontMono
                    font.pointSize: 8
                    color:          Theme.fgSecondary
                    Layout.preferredWidth: root.brightnessActionFailed ? 78 : 32
                    horizontalAlignment:   Text.AlignRight
                }
            }

            // ── Volume row ────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                implicitHeight:   Theme.captionHeight
                spacing:          Theme.spacingSm
                visible:          root.volumeAvail

                Text {
                    text:           "VOL"
                    font.family:    Theme.fontUi
                    font.pointSize: 8
                    color:          Theme.fgMuted
                    Layout.preferredWidth: 30
                }

                Text {
                    visible:        root.volumeLevel < 0
                    text:           "--"
                    font.family:    Theme.fontMono
                    font.pointSize: 8
                    color:          Theme.fgMuted
                    Layout.fillWidth: true
                }

                Slider {
                    id:               volumeSlider
                    Layout.fillWidth: true
                    visible:          root.volumeLevel >= 0
                    from: 0;  to: 1;  stepSize: 0.01
                    value: root.volumeLevel >= 0 ? root.volumeLevel : 0
                    onMoved: {
                        const level = Math.round(volumeSlider.value * 100) / 100;
                        root.volumeLevel = level;  // optimistic update
                        root.requestVolumeWrite(level);
                    }
                }

                Text {
                    visible:        root.volumeActionFailed
                    text:           "ACTION FAILED"
                    font.family:    Theme.fontMono
                    font.pointSize: 8
                    color:          Theme.fgMuted
                }

                Rectangle {
                    visible:        root.volumeLevel >= 0
                    implicitWidth:  muteLabel.implicitWidth + Theme.spacingSm * 2
                    implicitHeight: Theme.captionHeight - Theme.spacingSm * 2
                    color:          Theme.bgFill
                    border.width:   Theme.border
                    border.color:   Theme.lineEdge

                    Text {
                        id:               muteLabel
                        anchors.centerIn: parent
                        text:             "MUTE"
                        font.family:      Theme.fontUi
                        font.pointSize:   8
                        color: root.volumeMuted ? Theme.fgPrimary : Theme.fgMuted
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: {
                            if (!volumeMuteProc.running) {
                                root.volumeActionFailed = false;
                                volumeMuteProc.running = true;
                            }
                        }
                    }
                }
            }

            // ── Wi-Fi row ─────────────────────────────────────────────────
            // Radio power, connection state, and SSID are rendered separately.
            // Failures stay visible rather than disappearing as a false "off".
            RowLayout {
                Layout.fillWidth: true
                implicitHeight:   Theme.captionHeight
                spacing:          Theme.spacingSm

                Text {
                    text:           "WIFI"
                    font.family:    Theme.fontUi
                    font.pointSize: 8
                    color:          Theme.fgMuted
                    Layout.preferredWidth: 30
                }

                Text {
                    Layout.fillWidth: true
                    text: {
                        if (wifiToggleProc.running)    return "switching…";
                        if (root.wifiActionFailed)     return "ACTION FAILED";
                        if (root.wifiStatusFailed)     return "STATUS FAILED";
                        if (!root.wifiAvail)           return "---";
                        if (!root.wifiPowered)         return "radio off";
                        if (root.wifiState === "connected")
                            return root.wifiNetwork || "connected";
                        return root.wifiState || "---";
                    }
                    font.family:    Theme.fontMono
                    font.pointSize: 8
                    color:          root.wifiAvail && root.wifiPowered
                                    ? Theme.fgPrimary : Theme.fgMuted
                    elide:          Text.ElideRight
                }

                Button {
                    id: wifiPowerButton
                    text: root.wifiPowered ? "OFF" : "ON"
                    activeFocusOnTab: true
                    enabled: !wifiToggleProc.running && !wifiConfigureProc.running
                    implicitWidth: contentItem.implicitWidth + Theme.spacingSm * 2
                    implicitHeight: Theme.captionHeight - Theme.spacingSm * 2
                    background: Rectangle {
                        color:        Theme.bgFill
                        border.width: Theme.border
                        border.color: parent.activeFocus ? Theme.stateFocus : Theme.lineEdge
                    }
                    contentItem: Text {
                        text:             wifiPowerButton.text
                        font.family:      Theme.fontUi
                        font.pointSize:   8
                        color:            Theme.fgPrimary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment:   Text.AlignVCenter
                    }
                    onClicked: {
                        root.wifiActionFailed = false;
                        wifiToggleProc.running = true;
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }

                Button {
                    id: wifiConfigureButton
                    text: wifiConfigureProc.running ? "OPEN…" : "CONFIGURE"
                    activeFocusOnTab: true
                    enabled: !wifiToggleProc.running && !wifiConfigureProc.running
                    implicitWidth: contentItem.implicitWidth + Theme.spacingSm * 2
                    implicitHeight: Theme.captionHeight - Theme.spacingSm * 2
                    background: Rectangle {
                        color:        Theme.bgFill
                        border.width: Theme.border
                        border.color: parent.activeFocus ? Theme.stateFocus : Theme.lineEdge
                    }
                    contentItem: Text {
                        text:             wifiConfigureButton.text
                        font.family:      Theme.fontUi
                        font.pointSize:   8
                        color:            Theme.fgPrimary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment:   Text.AlignVCenter
                    }
                    onClicked: {
                        root.wifiActionFailed = false;
                        wifiConfigureProc.running = true;
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
            }

            // ── Bluetooth row ─────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                implicitHeight:   Theme.captionHeight
                spacing:          Theme.spacingSm

                Text {
                    text:           "BT"
                    font.family:    Theme.fontUi
                    font.pointSize: 8
                    color:          Theme.fgMuted
                    Layout.preferredWidth: 30
                }

                Text {
                    Layout.fillWidth: true
                    text: {
                        if (btToggleProc.running) return "switching…";
                        if (root.btFailed)        return "TOGGLE FAILED";
                        if (!root.btAvail)        return "---";
                        return root.btPowered ? "on" : "off";
                    }
                    font.family:    Theme.fontMono
                    font.pointSize: 8
                    color: root.btAvail && root.btPowered && !root.btFailed
                           ? Theme.fgPrimary : Theme.fgMuted
                }

                Button {
                    id: btPowerButton
                    text: btToggleProc.running ? "WAIT"
                          : root.btFailed ? "RETRY"
                          : root.btPowered ? "OFF" : "ON"
                    activeFocusOnTab: true
                    enabled: !btToggleProc.running
                    implicitWidth: contentItem.implicitWidth + Theme.spacingSm * 2
                    implicitHeight: Theme.captionHeight - Theme.spacingSm * 2
                    background: Rectangle {
                        color:        Theme.bgFill
                        border.width: Theme.border
                        border.color: parent.activeFocus ? Theme.stateFocus : Theme.lineEdge
                    }
                    contentItem: Text {
                        text:             btPowerButton.text
                        font.family:      Theme.fontUi
                        font.pointSize:   8
                        color:            Theme.fgPrimary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment:   Text.AlignVCenter
                    }
                    onClicked: {
                        root.btFailed = false;
                        btToggleProc.running = true;
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
            }

        }
    }
}
