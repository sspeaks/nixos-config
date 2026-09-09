# Plate XIV System Status/Control - Planning Summary

**For:** Morpheus (Lead/Aesthetic Director)  
**From:** Switch (Bars, Widgets & Menus)  
**Date:** 2026-08-07  
**Scope:** Non-implementation planning for 5 system features in ControlCenter

---

## What to Add

1. **Wi-Fi Status & Control** → iwd CLI (polling)
2. **Bluetooth Status & Control** → BlueZ D-Bus + bluetoothctl CLI
3. **Audio/Volume** → Pipewire pactl (polling)
4. **Brightness** → brightnessctl CLI (polling)
5. **Battery Extension** → UPower (already present; add charging state)

---

## Key Constraints

- **Quickshell is QML-only.** No native async/await; use Timer for polling.
- **iwd has no D-Bus binding.** Must use CLI + polling (1 sec, only while visible).
- **Polling happens only when ControlCenter is open.** No idle CPU impact.
- **All styling via Theme.qml singletons.** No hardcoded colors.
- **Current width is 260px.** Layout must not overflow; decide if sections collapse.

---

## Architecture at a Glance

| Feature | Backend | Type | Polling? | Challenge |
|---------|---------|------|----------|-----------|
| Wi-Fi | iwd CLI | Read+Control | Yes (1s) | IPC-only, no D-Bus |
| Bluetooth | BlueZ D-Bus | Read+Control | No* | Event-driven signals |
| Audio | pactl CLI | Read+Control | Yes (1s) | CLI only; lag possible |
| Brightness | brightnessctl CLI | Read+Control | Yes (1s) | May need sudo |
| Battery | UPower D-Bus | Read-only | No | Already working |

*Bluetooth: Can use D-Bus signals; polling only for device list refresh.

---

## Quick Checklist for Morpheus

**Before Design Phase:**
- [ ] Verify Quickshell D-Bus support (do we have Bluetooth bindings?)
- [ ] Check: Does brightnessctl work without sudo on Asahi ARM?
- [ ] Confirm: pactl or wpctl available in flake?
- [ ] Layout: Can 4 new sections fit in 260px, or do they fold/collapse?

**Design Phase (Morpheus):**
- [ ] Sketch layout: Status display + quick-action buttons per section
- [ ] Mock colors/typography using Plate XIV tokens
- [ ] Define interactive states: loading spinner, error toast, disabled
- [ ] Decide: Inline in ControlCenter.qml or extracted components?

**Implementation Phase (Morpheus/Switch):**
- [ ] Bluetooth (simplest D-Bus)
- [ ] Wi-Fi (polling, network picker)
- [ ] Audio (volume slider)
- [ ] Brightness (brightness slider)
- [ ] Battery (charging state overlay)

**Validation Phase:**
- [ ] Manual QML preview: `quickshell -c plate-xiv`
- [ ] Live session: `Mod+Shift+Space` to toggle
- [ ] No crashes if services missing
- [ ] Memory stable after 10 min active use

---

## Files to Touch

**Modify:**
- `home/features/quickshell/plate-xiv/ControlCenter.qml` (main implementation)
- `home/features/quickshell/default.nix` (if dbus access needed)

**Possibly Create** (Morpheus decides if > 200 LOC):
- `WifiStatus.qml`
- `BluetoothStatus.qml`
- `AudioStatus.qml`
- `BrightnessStatus.qml`

---

## Known Unknowns

1. **Quickshell Bluetooth D-Bus bindings?** Check qml docs.
2. **brightnessctl sudo requirement?** Test on actual hardware.
3. **pactl vs wpctl?** Verify which is available.
4. **Max ControlCenter height?** Does it collide with Launcher?
5. **Polling performance?** Does 1 sec interval cause lag?

---

## Failure Modes (Defensive Required)

| Failure | Impact | Mitigation |
|---------|--------|-----------|
| iwd daemon stops | Can't control Wi-Fi | Hide section; show "unavailable" |
| BlueZ daemon stops | Can't control Bluetooth | Hide section gracefully |
| Pipewire stops | Volume control broken | Disable slider; show "offline" |
| brightnessctl permission denied | Can't adjust brightness | Document sudo workaround |
| ControlCenter grows too tall | Overlaps Launcher/Notifications | Decide fold/scroll/split strategy |

---

## Next Steps (You Own This)

1. **Review planning decision** (f281eb15-...) for detailed rationale
2. **Validate architecture** against Quickshell capabilities
3. **Sketch visual design** using Plate XIV palette
4. **Identify unknowns** (especially sudo & Bluetooth bindings)
5. **Open implementation** or request Switch clarifications

---

## References

- **Full Planning:** `.squad/decisions/inbox/Switch-plate-xiv-system-status-control-features-morpheus-*.md`
- **Command Reference:** `.squad/memory/policy-inbox/plate-xiv-system-control-reference.md`
- **Current ControlCenter:** `home/features/quickshell/plate-xiv/ControlCenter.qml`
- **Theme System:** `home/features/quickshell/default.nix` (Theme.qml generation)

---

**Status:** ✅ Planning complete. Awaiting Morpheus design validation.  
**Decision ID:** f281eb15-1733-4267-950e-90b0b1c8ef27
