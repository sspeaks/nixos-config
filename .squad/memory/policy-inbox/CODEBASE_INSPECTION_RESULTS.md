# Plate XIV - Codebase Inspection Results

**Date:** 2026-08-07  
**Inspector:** Switch  
**Purpose:** Baseline state documentation for implementation planning

---

## Current ControlCenter.qml State

**Location:** `home/features/quickshell/plate-xiv/ControlCenter.qml`  
**Lines:** ~180  
**Current Features:**
- Clock display (HH:MM:SS, dddd MMMM d)
- Battery percentage (UPower, hidden if no device)
- Lock button (hyprlock)
- Logout button (wlogout)

**Current Services Used:**
```qml
import Quickshell.Services.UPower
import Quickshell.Io
import Quickshell.Wayland
```

**Theme System:**
- Uses Theme.* singletons (colors, spacing, fonts)
- Theme.qml generated from `home/features/theme/plate.nix`
- All colors/tokens defined; no hardcoding

**Layout:**
- Panel width: 260px (fixed)
- Panel height: implicitHeight + Theme.spacingLg * 2
- Layer: Top, keyboardFocus: None, exclusiveZone: 0
- Margins: top = Theme.captionHeight + Theme.spacingLg; right = Theme.spacingLg

**IPC:**
```qml
IpcHandler {
    target: "controlCenter"
    function toggle(): void { root.visible = !root.visible; }
}
```
Bound to: `Mod+Shift+Space` in niri config

---

## Available Quickshell Modules (Observed in Codebase)

### Currently Used
- `QtQuick` (standard QML)
- `Quickshell` (root, execDetached, screens)
- `Quickshell.Io` (execProcess, SystemClock)
- `Quickshell.Wayland` (WlrLayershell, WlrLayer, WlrKeyboardFocus)
- `Quickshell.Services.UPower` (battery)
- `Quickshell.Services.Notifications` (NotificationCard.qml)
- `Quickshell.WindowManager` (WorkspaceRibbon.qml)

### NOT Currently Used (Need Verification)
- `Quickshell.Services.DBus` (for Bluetooth D-Bus binding)
- `Quickshell.Services.Systemd` (for service monitoring)
- Any audio/brightness/wifi native bindings

---

## System Tools - Availability Check

| Tool | Found | Location | Status |
|------|-------|----------|--------|
| `iwctl` | ✅ | `/run/current-system/sw/bin/iwctl` | Ready |
| `bluetoothctl` | ✅ | `/run/current-system/sw/bin/bluetoothctl` | Ready |
| `brightnessctl` | ✅ | `/etc/profiles/per-user/sspeaks/bin/brightnessctl` | Ready |
| `pactl` | ❓ | Not found in PATH | Needs verification |
| `wpctl` | ❓ | Not found in PATH | Needs verification |
| `nmcli` | ❌ | Not found | NetworkManager not enabled |
| `acpi` | ❌ | Not found | Not installed |

---

## NixOS Configuration State

### Networking
**Config:** `networking.wireless.iwd.enable = true`  
**Services:** iwd (Intel Wireless Daemon)  
**No:** NetworkManager, wpa_supplicant, connman  

### Audio
**Status:** No explicit config found in grep; may use home-manager defaults  
**Expected:** pipewire or pulseaudio enabled  
**Action:** Verify in `/etc/nixos/configuration.nix` or home-manager output

### Bluetooth
**Status:** No explicit config found in grep  
**Expected:** services.bluez.enable = true (or in home-manager)  
**Action:** Verify if enabled; enable if not

### Brightness
**Status:** brightnessctl available in PATH  
**No explicit service config:** sysfs-based, no daemon needed  
**Potential issue:** Sudo requirement on ARM (Asahi macOS)

### Battery/Power
**Service:** UPower (org.freedesktop.UPower)  
**Status:** Working (ControlCenter already uses it)  
**No:** Custom ACPI handling; relying on UPower

---

## Feature-Specific Analysis

### Wi-Fi (iwd)
✅ **CLI tool available:** iwctl  
✅ **Service running:** networking.wireless.iwd.enable = true  
❌ **D-Bus binding:** iwd uses IPC (/run/iwd/), not standard D-Bus  
❌ **Quickshell native support:** Not observed  
**Implementation:** CLI polling via execProcess()

**IPC socket location:** `/run/iwd/`  
**CLI commands verified:**
```bash
iwctl station wlan0 show              # Status
iwctl station wlan0 get-networks      # Scan
iwctl station wlan0 connect SSID      # Connect
iwctl device wlan0 set-property Powered on|off  # Power
```

### Bluetooth (BlueZ)
✅ **CLI tool available:** bluetoothctl  
❓ **Service enabled:** Needs verification  
❓ **D-Bus binding in Quickshell:** Needs verification  
**D-Bus interface exists:** org.bluez (standard BlueZ D-Bus API)  
**Implementation:** D-Bus if Quickshell supports it; CLI fallback

**D-Bus paths (if accessible):**
```
/org/bluez/hci0                    # Adapter
/org/bluez/hci0/dev_XX_XX_XX_XX_XX_XX  # Device
```

### Audio (Pipewire/Pulseaudio)
❓ **Service enabled:** Needs verification  
❌ **CLI tools:** pactl not in PATH (may not be installed)  
❓ **wpctl available:** Needs verification  
**Implementation:** Requires pactl or wpctl; poll-based

**Fallback:** If no CLI tool, gracefully disable audio widget

### Brightness (brightnessctl)
✅ **CLI tool available:** brightnessctl  
❌ **No daemon:** sysfs-based, direct hardware access  
⚠️ **Sudo requirement:** ARM (Asahi) may require elevated permissions  
**Implementation:** CLI via execProcess(); handle permission errors

**Sysfs location:**
```bash
ls /sys/class/backlight/  # Find device name
```

### Battery (UPower)
✅ **Service available:** UPower D-Bus  
✅ **Already integrated:** ControlCenter.qml imports UPower  
✅ **Event-driven:** PropertiesChanged signals work  
**Current usage:** `UPower.displayDevice.percentage`  
**Extension needed:** `.state`, `.timeToFull`, `.timeToEmpty`

---

## Theme System Architecture

**Generated:** `home/features/quickshell/default.nix` generates Theme.qml at build time  
**Source:** `home/features/theme/plate.nix` contains design tokens  

**Available tokens (from ControlCenter.qml usage):**
```qml
Theme.bgRaised      // Panel background
Theme.bgFill        // Button/input background
Theme.lineEdge      // Border color
Theme.fgPrimary     // Main text
Theme.fgSecondary   // Secondary text
Theme.fgMuted       // Tertiary/disabled text

Theme.fontMono      // Fixed-width font
Theme.fontUi        // UI font
Theme.border        // Border width (px)
Theme.spacingSm     // Small gap
Theme.spacingLg     // Large/outer gap
Theme.captionHeight // Caption bar height (28px)
```

**Add new tokens by extending plate.nix, then regenerating Theme.qml via `home-manager switch`**

---

## Limits & Constraints

| Constraint | Value | Impact |
|-----------|-------|--------|
| Panel width | 260px | Sections may need to collapse or wrap |
| Panel layer | Top (exclusive-zone 0) | No blocking other windows; notifications can overlap |
| Keyboard focus | None | No text input; all mouse-driven |
| Refresh while hidden | No (Timer.running: root.visible) | No background polling drain |
| Quickshell version | Default nixpkgs | May limit available service modules |

---

## Files to Review Before Implementation

1. **Quickshell documentation** (QML modules, D-Bus capabilities, execProcess patterns)
2. **Plate XIV theme specification** (home/features/theme/plate.nix for color/spacing additions)
3. **ControlCenter.qml** (exact layout/ColumnLayout structure for adding sections)
4. **Niri keybinds** (config.kdl.nix for any additional shortcuts needed)

---

## Handoff Checklist for Morpheus

- [ ] Review current ControlCenter.qml architecture
- [ ] Verify Quickshell.Services.DBus availability (for Bluetooth)
- [ ] Test brightnessctl on Asahi ARM (sudo issue?)
- [ ] Confirm pactl or wpctl in flake dependencies
- [ ] Sketch layout for 4 new sections in 260px width
- [ ] Decide: inline or extracted components?
- [ ] Get Switch's clarification on any unknowns before implementation

---

**Status:** Inspection complete. Ready for design phase.  
**Confidence:** Medium (several "verify" items needed before impl)  
**Blockers:** None identified; all tools available, but some config state needs checking.
