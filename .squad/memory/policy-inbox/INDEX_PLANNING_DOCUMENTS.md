# Plate XIV System Status & Control - Planning Documents Index

**Prepared by:** Switch (Bars, Widgets & Menus specialist)  
**Date:** 2026-08-07  
**For:** Morpheus (Lead/Aesthetic Director) — Design & Implementation  
**Status:** ✅ READY FOR HANDOFF

---

## Planning Document Location Map

All documents persisted to **governed state** (no manual edits):
- 📋 **Squad Decision:** `.squad/decisions/inbox/Switch-plate-xiv-system-status-control-features-morpheus-*.md`
- 📚 **Reference Inbox:** `.squad/memory/policy-inbox/`

---

## What's Ready (In Priority Order for Morpheus)

### 1. **Quick Summary (START HERE)**
📄 **File:** `.squad/memory/policy-inbox/PLATE_XIV_PLANNING_SUMMARY.md`  
**Time to read:** 5 min  
**Purpose:** Executive overview of what to build, constraints, and next steps  
**For:** Quick context before diving into details

**Contains:**
- ✅ What to add (5 features)
- ✅ Key constraints (QML-only, polling strategy, 260px width)
- ✅ Architecture table
- ✅ Morpheus's checklist (design/impl phases)
- ✅ Failure modes overview

---

### 2. **Codebase Inspection Results (THEN REVIEW THIS)**
📄 **File:** `.squad/memory/policy-inbox/CODEBASE_INSPECTION_RESULTS.md`  
**Time to read:** 10 min  
**Purpose:** Baseline state of ControlCenter, available tools, NixOS config  
**For:** Understanding current architecture before design

**Contains:**
- ✅ ControlCenter.qml current state (clock, battery, buttons)
- ✅ Quickshell modules already in use
- ✅ System tools availability matrix (iwctl, bluetoothctl, brightnessctl, pactl?)
- ✅ NixOS service configuration state (iwd: yes, pipewire?: unknown, bluez?: unknown)
- ✅ Feature-specific analysis (what's ready, what needs verifying)
- ✅ Theme system architecture
- ✅ Constraints & limits
- ✅ Handoff checklist

---

### 3. **Full Planning Decision (FOR DETAILED RATIONALE)**
📄 **File:** `.squad/decisions/inbox/Switch-plate-xiv-system-status-control-features-morpheus-*.md`  
**Time to read:** 20 min (detailed)  
**Purpose:** Complete planning document with rationale, failure analysis, acceptance tests  
**For:** Understanding "why" behind each decision

**Contains:**
- ✅ Feature scope (Wi-Fi, Bluetooth, Audio, Brightness, Battery)
- ✅ Current state assessment
- ✅ Backend commands & APIs (detailed mapping per feature)
- ✅ State refresh & event strategy (event-driven vs polling)
- ✅ Failure modes & resilience table
- ✅ Required NixOS packages/services
- ✅ Exact likely files to modify/create
- ✅ Acceptance tests (functional, system, design tests)
- ✅ Implementation notes (architectural constraints, known unknowns, testing hooks)
- ✅ Rollout plan (design → impl → validation → review)

---

### 4. **Command Reference (FOR IMPLEMENTATION)**
📄 **File:** `.squad/memory/policy-inbox/plate-xiv-system-control-reference.md`  
**Time to read:** 10 min (grep as needed during impl)  
**Purpose:** Copy-paste CLI commands, QML integration patterns, blockers/workarounds  
**For:** During implementation phase (keep open in another window)

**Contains:**
- ✅ Command cheat sheet (iwctl, bluetoothctl, pactl, brightnessctl, upower)
- ✅ QML integration patterns (CLI execution, D-Bus polling, slider binding)
- ✅ Blocker/workaround pairs (sudo, iwd IPC, pipewire stability)
- ✅ Device paths & D-Bus locations
- ✅ Service enable checks (systemctl commands)
- ✅ Testing checklist

---

## Morpheus's Action Items (In Order)

### Phase 1: Validation (Pre-Design)
**Goal:** Resolve unknowns before committing to layout  
**Effort:** 30 min  

- [ ] **Quickshell modules:** Verify `Quickshell.Services.DBus` exists (for Bluetooth)
- [ ] **Audio tools:** Confirm pactl or wpctl in flake dependencies
- [ ] **Brightness sudo:** Test brightnessctl on actual Asahi ARM hardware
- [ ] **Panel height:** Prototype layout with 4 new sections; does it overflow 260px?

**Blockers resolved? → Continue to Phase 2**

### Phase 2: Visual Design (Your specialty!)
**Goal:** Create detailed design spec that Switch can implement  
**Effort:** 1-2 hours  

- [ ] Sketch layout (status rows + quick-action buttons per feature)
- [ ] Mock colors/spacing using existing Plate XIV palette
- [ ] Define interactive states (enabled, loading, error, disabled)
- [ ] Decide: Inline in ControlCenter.qml or extract 4 new `.qml` components?
- [ ] Document any new Theme tokens needed (if colors don't fit existing palette)
- [ ] Create mock screenshots (design validation)

**Design frozen? → Handoff to Switch for Implementation**

### Phase 3: Implementation (Switch leads; Morpheus validates)
**Effort:** Coordinated with Switch  

- [ ] Bluetooth widget (simplest D-Bus)
- [ ] Wi-Fi widget (polling, network picker)
- [ ] Audio widget (volume slider)
- [ ] Brightness widget (brightness slider)
- [ ] Battery widget enhancement (charging state)

**Each component: impl → local test → design review → merge**

### Phase 4: Validation
**Goal:** No crashes, memory stable, graceful fallbacks  

- [ ] Manual preview: `quickshell -c plate-xiv`
- [ ] Live session: `Mod+Shift+Space` toggle
- [ ] Stop services (iwd, BlueZ, Pipewire) → verify no crashes
- [ ] 10 min stress test (ControlCenter open) → check memory/CPU

---

## Known Unknowns (Resolve in Phase 1)

| Unknown | Why It Matters | Where to Check |
|---------|---------------|-----------------|
| Quickshell.Services.DBus availability | Bluetooth impl path (D-Bus vs CLI) | Quickshell docs / try import |
| pactl or wpctl in flake | Audio impl path (CLI tool needed) | `nix flake show`; test in shell |
| brightnessctl sudo permission | Asahi ARM device access | `sudo brightnessctl set 50%`; check sysfs |
| Panel height with 4 new sections | Layout overflow or collapse strategy | QML prototype in editor |
| Max ControlCenter height (collision?) | Does panel block other surfaces? | Test with Launcher visible |
| Polling performance (1 sec too fast?) | CPU/battery impact | Profiler after impl |

---

## Failure Modes Summary (For Design)

| Failure | User Impact | Design Mitigation |
|---------|------------|-------------------|
| iwd/BlueZ/Pipewire daemon stops | Widget shows wrong state or frozen | Hide section; show "unavailable" icon |
| CLI timeout (network error) | Control unresponsive | Timeout after 2s; show spinner; disable buttons |
| brightnessctl permission denied | Brightness slider disabled | Show lock icon; document sudo workaround in UI |
| ControlCenter grows too tall | Overlaps other surfaces | Decide: fold sections, scroll, or split panel |
| Device not present (VM, thin client) | Widget irrelevant | Hidden by default (already doing for battery) |

---

## Quick Reference for Implementation (Switch)

### For each feature (same pattern):

1. **Status display** (read-only)
   - Event-driven D-Bus: UPower (battery), BlueZ (bluetooth)
   - Polling CLI: iwd, pactl, brightnessctl

2. **Control buttons** (write-side)
   - On-click: `Quickshell.execProcess([cmd...], callback)`
   - Show spinner during operation
   - Timeout after 2-5s; show error toast if failed

3. **Error handling**
   - Catch null/undefined states
   - Log to stdout/journal
   - Graceful fallback (hide or disable widget)

4. **Styling**
   - All colors from Theme.* singletons
   - All spacing from Theme.spacingSm / spacingLg
   - Match ControlCenter existing font/sizing (9pt mono for labels)

---

## Files You'll Touch (Implementation)

**Modify:**
```
home/features/quickshell/plate-xiv/ControlCenter.qml
home/features/quickshell/default.nix  (if dbus access needed)
```

**Possibly create** (if > 200 LOC):
```
home/features/quickshell/plate-xiv/WifiStatus.qml
home/features/quickshell/plate-xiv/BluetoothStatus.qml
home/features/quickshell/plate-xiv/AudioStatus.qml
home/features/quickshell/plate-xiv/BrightnessStatus.qml
```

---

## Testing & Validation (Before Merge)

**Manual tests:**
```bash
# Preview
quickshell -c plate-xiv

# Live session
Mod+Shift+Space  # Toggle ControlCenter
```

**CLI validation (before impl):**
```bash
iwctl station wlan0 show
bluetoothctl devices
pactl get-sink-volume @DEFAULT_SINK@
brightnessctl get
upower -i /org/freedesktop/UPower/devices/battery_BAT0
```

**System state checks:**
```bash
systemctl is-enabled iwd
systemctl is-enabled bluetooth
systemctl --user is-enabled pipewire.socket
```

---

## Decision Summary

**Status:** ✅ PLANNING COMPLETE — No implementation decisions made yet  
**Next:** Morpheus design validation (Phase 1 unknowns)  
**Decision ID:** f281eb15-1733-4267-950e-90b0b1c8ef27

**References:**
- Full planning decision (Squad inbox)
- Command reference (Policy inbox)
- Codebase inspection (Policy inbox)
- Summary (Policy inbox)

---

**Handoff Ready:** All planning documents persisted to governed state.  
**No Implementation:** This is analysis only.  
**No Code Changes:** No ControlCenter.qml edits yet.  
**No Config Changes:** No NixOS package changes yet.

**Morpheus:** You own design phase. Switch stands by for clarifications and implementation.

