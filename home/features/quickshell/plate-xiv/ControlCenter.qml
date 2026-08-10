// ControlCenter — Plate XIV status/quick-action panel
//
// D23 groups this with the notification surfaces under one layer-shell
// contract: layer Top, exclusiveZone 0, keyboardFocus None — positioned
// below the caption at top margin = Theme.captionHeight + Theme.spacingLg.
// keyboardFocus None is intentional even though this panel has clickable
// controls: everything here is mouse-driven (chips, buttons, sliders),
// nothing needs text entry, so it never has to compete with the launcher
// for keyboard grab.
//
// IPC: D23 authored this panel's *content* contract but never named an
// IPC target or niri keybind for opening it, so this file exposes
// `target: "controlCenter"`, function `toggle()` — mirroring the
// launcher's D10 shape exactly. Trinity has since landed the niri side:
// `Mod+Shift+Space` in config.kdl.nix calls
// `qs ipc -c plate-xiv call controlCenter toggle` (the corrected argument
// order — `-c`/`--config` belongs to `qs ipc`, not `ipc call`; see the
// trinity-niri-batch2-* inbox note for the D10 correction record), so this
// panel is reachable in a live niri session.
//
// Batch 3 — five system-control rows (D32):
//   battery status  · UPower.displayDevice (already imported, enhanced)
//   brightness      · plate-brightness-get / plate-brightness-set (Tank D32 wrappers)
//   volume + mute   · plate-volume-get / plate-volume-set / plate-volume-toggle-mute
//   Wi-Fi           · plate-wifi-status / plate-wifi-toggle / plate-wifi-configure
//   Bluetooth       · plate-bluetooth-status / plate-bluetooth-toggle
//
// All five use Tank's plate-controls wrapper binaries (packages/plate-controls,
// added to environment.systemPackages in hosts/asahi/desktop.nix).  QML never
// calls raw CLI tools directly — wrappers own device names, argument order, and
// output contracts so this file stays compositor-agnostic.
//
// Polling contract: all five run on a 3 s timer *only while visible*; the
// timer starts on show, stops on hide, and all in-flight processes are
// cancelled on hide.  Explicitly loading/error/unsupported states are shown
// for every row — no silent success-shaped defaults.
//
// Wrapper stdout contracts (Tank D32 — these are the only strings parsed here):
//   plate-brightness-get  → "CURRENT MAX"    e.g. "420 800"
//   plate-brightness-set  → (no stdout)       arg: integer 0-100
//   plate-volume-get      → "VOL MUTED"       e.g. "0.72 0" or "0.50 1"
//   plate-volume-set      → (no stdout)       arg: float 0.0-1.0
//   plate-volume-toggle-mute → (no stdout)
//   plate-wifi-status     → "POWERED STATE SSID" e.g. "1 connected HomeNet"
//                                                   or "0 disconnected "
//   plate-wifi-toggle     → (no stdout)
//   plate-wifi-configure  → launches the graphical network configurator
//   plate-bluetooth-status → "POWERED COUNT"  e.g. "1 2" (powered=1, 2 connected)
//   plate-bluetooth-toggle → (no stdout)
//   All wrappers: exit non-0 + stderr message when hardware/daemon absent.

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
    // Runs every 3 s while visible; cancelled immediately on hide.
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
            // Cancel in-flight processes.
            brightnessGetProc.running = false;
            volumeReadProc.running    = false;
            wifiStatusProc.running    = false;
            btStatusProc.running      = false;
        }
    }

    // ── Brightness processes ──────────────────────────────────────────────
    // Read: `plate-brightness-get` → "CURRENT MAX" e.g. "420 800"
    // Percentage derived: round(cur / max * 100). Wrapper targets apple-panel-bl
    // explicitly (Tank D32) — device name not repeated here.
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
    // Read: `plate-volume-get` → "VOL MUTED"  e.g. "0.72 0" or "0.50 1"
    // VOL is already 0.0-1.0 — no conversion needed for the slider.
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

    // Mute toggle: `plate-volume-toggle-mute` — no args.
    // Re-reads volume after toggle so mute indicator updates immediately.
    Process {
        id:      volumeMuteProc
        command: ["plate-volume-toggle-mute"]
        running: false
        onExited: function(code, _status) {
            root.volumeActionFailed = code !== 0;
            if (!volumeReadProc.running) volumeReadProc.running = true;
        }
    }

    // ── Wi-Fi processes ───────────────────────────────────────────────────
    // Status: `plate-wifi-status` → "POWERED STATE SSID". POWERED, connection
    // state, and SSID are deliberately independent; an enabled radio can be
    // disconnected and SSID may be empty.
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

    // Toggle through the Plate helper, then re-poll status.
    Process {
        id:      wifiToggleProc
        command: ["plate-wifi-toggle"]
        running: false
        onExited: function(code, _status) {
            root.wifiActionFailed = code !== 0;
            root.pollWifi();
        }
    }

    Process {
        id:      wifiConfigureProc
        command: ["plate-wifi-configure"]
        running: false
        onExited: function(code, _status) {
            root.wifiActionFailed = code !== 0;
            root.pollWifi();
        }
    }

    // ── Bluetooth processes ───────────────────────────────────────────────
    // Status: `plate-bluetooth-status` → "POWERED CONNECTED"
    //   POWERED = 0|1, CONNECTED = count of connected devices.
    //   Exit non-0 when no adapter or backend service is available.
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
            if (root.btRepollPending && !btToggleProc.running) {
                root.btRepollPending = false;
                Qt.callLater(function() { root.pollBluetooth(); });
            }
        }
    }

    // The button starts only this helper. Completion is always followed by a
    // status poll, including failures, so UI state never relies on optimism.
    Process {
        id:      btToggleProc
        command: ["plate-bluetooth-toggle"]
        running: false
        onExited: function(code, _status) {
            root.btFailed = code !== 0;
            Qt.callLater(function() {
                if (btStatusProc.running) {
                    root.btRepollPending = true;
                } else {
                    root.pollBluetooth();
                }
            });
        }
    }

    // ── IPC ───────────────────────────────────────────────────────────────
    // Mirrors the launcher's D10 IPC shape (see file header note).
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

                // Mini progress bar.
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
            // Hidden permanently once brightnessctl confirms no backlight.
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

                // Loading state: show "--" until first value arrives.
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
                    // Bind value only when not currently being dragged so poll
                    // updates flow in without fighting the user's drag gesture.
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
            // Hidden permanently once wpctl confirms no default sink.
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

                // Loading state.
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

                // Mute toggle button: dim when muted.
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
                        // Dimmed when muted to show the muted state visually.
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

                // State / network label.
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

            // ── Divider ───────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight:   Theme.border
                color:            Theme.lineRule
            }

            // ── Quick actions ─────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spacingSm
                spacing:          Theme.spacingSm

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: lockLabel.implicitHeight + Theme.spacingSm * 2
                    color:          Theme.bgFill
                    border.width:   Theme.border
                    border.color:   Theme.lineEdge

                    Text {
                        id:               lockLabel
                        anchors.centerIn: parent
                        text:             "LOCK"
                        font.family:      Theme.fontUi
                        font.pointSize:   9
                        color:            Theme.fgPrimary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: {
                            // hyprlock is compositor-agnostic (ext-session-lock-v1,
                            // D24) — same binary niri's own Mod+Shift+L bind calls.
                            Quickshell.execDetached(["hyprlock"]);
                            root.visible = false;
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: logoutLabel.implicitHeight + Theme.spacingSm * 2
                    color:          Theme.bgFill
                    border.width:   Theme.border
                    border.color:   Theme.lineEdge

                    Text {
                        id:               logoutLabel
                        anchors.centerIn: parent
                        text:             "LOGOUT"
                        font.family:      Theme.fontUi
                        font.pointSize:   9
                        color:            Theme.fgPrimary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: {
                            // wlogout owns the actual exit action (D24's
                            // plate-logout wrapper is wired inside its
                            // button, not duplicated here) — same binary
                            // niri's own Mod+Escape bind calls.
                            Quickshell.execDetached(["wlogout"]);
                            root.visible = false;
                        }
                    }
                }
            }
        }
    }
}
