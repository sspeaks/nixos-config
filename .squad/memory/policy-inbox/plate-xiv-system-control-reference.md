# Plate XIV System Control - Command Reference

**Author:** Switch  
**Purpose:** Quick lookup for backend commands and APIs  
**Related Decision:** f281eb15-1733-4267-950e-90b0b1c8ef27

---

## Command Cheat Sheet

### Wi-Fi (iwd)
```bash
# Status
iwctl station wlan0 show
iwctl device wlan0 show

# Scan networks
iwctl station wlan0 get-networks

# Connect
iwctl station wlan0 connect "SSID Name"

# Disconnect
iwctl station wlan0 disconnect

# Power on/off
iwctl device wlan0 set-property Powered on
iwctl device wlan0 set-property Powered off
```

### Bluetooth (BlueZ)
```bash
# List paired devices
bluetoothctl devices

# Connect
bluetoothctl connect 00:1A:7D:DA:71:13

# Disconnect
bluetoothctl disconnect 00:1A:7D:DA:71:13

# Power toggle
bluetoothctl power on
bluetoothctl power off

# Show adapter
bluetoothctl show
```

### Audio (Pulseaudio/Pipewire)
```bash
# Get volume
pactl get-sink-volume @DEFAULT_SINK@

# Set volume (absolute)
pactl set-sink-volume @DEFAULT_SINK@ 50%

# Mute toggle
pactl set-sink-mute @DEFAULT_SINK@ toggle

# Watch for changes
pactl subscribe
```

### Brightness (brightnessctl)
```bash
# Get current brightness
brightnessctl get

# Set absolute (percentage)
brightnessctl set 50%

# Increment/decrement
brightnessctl inc 10%
brightnessctl dec 10%
```

### Battery (UPower)
```bash
# Enumerate devices
upower -e

# Get device info
upower -i /org/freedesktop/UPower/devices/battery_BAT0

# Watch signals
dbus-monitor --system "interface='org.freedesktop.DBus.Properties'"
```

---

## Quickshell QML Integration Patterns

### CLI Execution (Poll-based)
```qml
import Quickshell.Io

Timer {
    interval: 1000
    running: root.visible
    onTriggered: {
        Quickshell.execProcess(
            ["pactl", "get-sink-volume", "@DEFAULT_SINK@"],
            (exit, stdout) => {
                if (exit === 0) {
                    let match = stdout.match(/(\d+)%/);
                    if (match) currentVolume = match[1] + "%";
                }
            }
        );
    }
}
```

### D-Bus Property Watch (Event-driven)
```qml
import Quickshell.Services.UPower

UPower.displayDevice.onChanged: {
    if (UPower.displayDevice) {
        batteryPercent = UPower.displayDevice.percentage;
        isCharging = UPower.displayDevice.state === 1;
    }
}
```

### Slider Binding
```qml
Slider {
    from: 0; to: 100; value: 50
    
    onMoved: {
        Quickshell.execProcess(
            ["brightnessctl", "set", value + "%"],
            (exit, stdout) => {
                if (exit !== 0) console.error("Failed to set brightness");
            }
        );
    }
}
```

---

## Potential Blockers & Workarounds

### Blocker: brightnessctl Requires Sudo
**Workaround:** udev rule or systemd user service (see planning document)

### Blocker: iwd IPC vs D-Bus
**Impact:** No native Quickshell D-Bus binding for iwd; CLI-only polling required

### Blocker: Pipewire CLI Stability
**Impact:** pactl may show stale values; consider wpctl if available

---

## Device Paths & D-Bus Locations

### Bluetooth Adapter Path
- Typically: `/org/bluez/hci0`
- Discover: `dbus-send --system --print-reply --dest=org.bluez / org.freedesktop.DBus.Introspectable.Introspect`

### Battery Device Path
- Typical: `/org/freedesktop/UPower/devices/battery_BAT0`
- Discover: `upower -e`

### Brightness Device
- Typical names: intel_backlight, amdgpu_bl0, apple_ple_backlight
- List: `brightnessctl --list`

---

## Service Enable Checks (Nix)

```bash
systemctl --user is-enabled pipewire.socket
systemctl is-enabled bluetooth
systemctl is-enabled iwd

systemctl --user status pipewire.socket
systemctl status bluetooth
systemctl status iwd
```

---

## Testing Checklist

- [ ] iwd daemon running
- [ ] BlueZ daemon running
- [ ] Pipewire/Pulseaudio running
- [ ] sysfs backlight exists
- [ ] All executables in PATH: brightnessctl, iwctl, bluetoothctl, pactl, upower

---

**Status:** Reference only — for Morpheus implementation team  
**Last Updated:** 2026-08-07
