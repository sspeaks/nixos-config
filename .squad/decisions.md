---

### 2026-08-08T15:58:16.477-07:00: Plate XIV forest wallpaper and system controls complete (consolidated)
**By:** Morpheus, Tank, Switch, Trinity, Mouse, Fact Checker
**What:** Plate XIV now uses a deterministic Old-Growth Survey conifer forest wallpaper, replacing the rejected sparse oak concept while retaining the monochrome technical-survey language. Morpheus visually reviewed the built artifact and APPROVED it. Control Center system controls are complete: Bluetooth includes rfkill recovery; Wi-Fi exposes status, toggle, and CONFIGURE behavior; volume and brightness have helper-backed sliders; battery remains read-only. niri and Hyprland carry identical XF86 volume/brightness bindings, and brightness maintains an XDG runtime user baseline. Helper interfaces use 5-point volume/brightness steps. `plate-wifi-status` emits `<POWERED> <STATE> <SSID>`, with QML parsing fields 0/1 and joining field 2 onward. Brightness set/step preflight `XDG_RUNTIME_DIR` and record the actual rounded percentage in `$XDG_RUNTIME_DIR/plate-brightness-user-pct`.
**Why:** The forest direction better satisfies the requested nature emphasis and Plate XIV's restrained drafting aesthetic. Stable helper contracts keep compositor bindings and QML behavior consistent. Explicit Wi-Fi power state supports reliable UI decisions and SSIDs containing spaces. Runtime brightness state prevents ambient automation from immediately overriding intentional user changes.

### 2026-08-08T15:58:16.477-07:00: Control slider serialization and reviewer lockout protocol (consolidated)
**By:** Fact Checker, Mouse, Tank
**What:** Rapid Control Center slider writes must be serialized and failures must remain visible. Mouse's queued revision fixed dropped updates but was rejected because Quickshell 0.3 `Process` may still report `running` during its `exited` handler, so immediately restarting there can race or be ignored. Tank's third-owner revision synchronously clears the local running state before scheduling the deferred queue flush; Fact Checker re-reviewed and APPROVED. Reviewer lockout was enforced strictly: after rejection the original owner did not revise again; ownership moved Switch/Mouse → Mouse → Tank across review cycles.
**Why:** Quickshell process completion and restart are not safely atomic inside `exited`; queue draining must occur only after state reflects completion. Strict lockout prevents authors from repeatedly patching their own rejected approach and guarantees an independent revision path.

### 2026-08-08T15:58:16.477-07:00: Hyprland remains the safe fallback
**By:** Morpheus, Trinity, Tank
**What:** niri may be the default session, but Hyprland remains installed, configured, and selectable in the SDDM session picker. No Hyprland removal is authorized. Identical XF86 media and brightness bindings are maintained in both compositors.
**Why:** Preserving a proven session provides a reversible fallback while live hardware behavior is validated.

## Status

Implementation and static/build checks are complete and Fact Checker approved the final controls revision. Remaining work is live hardware validation of Bluetooth/rfkill recovery, Wi-Fi actions, volume, brightness baseline behavior, battery reporting, compositor keybindings, and Hyprland fallback.


### 2026-08-21T21:43:00-07:00: Batch 4 Design Review — OSD, clipboard, capture/OCR, night-light
**By:** Morpheus, with Tank, Trinity, Switch, Fact Checker
**What:** Batch 4 will implement Plate XIV volume/brightness OSD, niri clipboard parity, shared screenshot/OCR wrappers, and a declarative `wlsunset` toggle. Switch exclusively owns Quickshell QML; Trinity exclusively owns niri/Hyprland bindings; Tank exclusively owns wrappers, package registration, the night-light module, and `hosts/asahi/desktop.nix`; Fact Checker owns validation. Shared capabilities must route through compositor-neutral `plate-*` wrappers. niri remains primary and Hyprland remains an intact fallback. Screen recording, action-menu work, Quickshell refactoring, Control Center night-light UI, extra OSD types, and automatic scheduling are deferred.
**Why:** Frozen interfaces and exclusive file ownership allow safe parallel implementation while keeping both compositor sessions aligned and protecting the Asahi integration bottleneck.


### 2026-08-21T22:42:13-07:00: Batch 5 Design Review — Screen recording + ActionMenu
**By:** Morpheus, with Tank, Switch, Trinity, Fact Checker
**What:** Batch 5 implements compositor-neutral screen recording (wf-recorder, libx264, mp4, software-only encode) and a declarative Plate XIV ActionMenu overlay. ActionMenu.qml (new, IPC target "actionMenu") owns all session/power/record actions, replacing wlogout at Mod+Escape. ControlCenter LOCK/LOGOUT quick-actions removed (no duplication). Bindings: Mod+Escape = actionMenu toggle (both compositors), Mod+Shift+R = record toggle (both compositors). Five new wrappers: plate-record-start/stop/toggle, plate-shutdown, plate-reboot. wf-recorder added to system packages. File ownership: Switch (QML, ControlCenter cleanup), Tank (wrappers/packages/Nix), Trinity (bindings). Fact Checker APPROVED after one rejected-then-resolved review cycle. Static gates PASS.
**Why:** ActionMenu cleanly separates session/power/record concern from ControlCenter (status+sliders) and Launcher (app picker). wf-recorder with software libx264 is the correct Asahi choice (no VAAPI). Static QML entries avoid runtime-mutable JSON coupling. Reviewer lockout discipline upheld (blockers resolved, not bypassed).


### 2026-08-21T23:09:00-07:00: Batch 5 runtime validation — generation 211
**By:** Fact Checker, Ralph
**What:** Three pre-FC-review implementation bugs fixed (import Quickshell.Io; HoverHandler.hovered not containsMouse; PanelWindow has no forceActiveFocus/Keys). All automatable runtime contracts validated: QML loads clean; all 5 IPC functions dispatch; wf-recorder produces valid MP4 (libx264, aarch64, niri wlr-screencopy); PID file lifecycle correct; double-start and stop-when-idle guards work; ControlCenter has no lock/logout; shutdown/reboot wrappers inspected only. Generation 211 active.
**Why:** Pre-FC-review bugs are correctable by original author without lockout trigger. Activation performed without reboot, logout, or display-manager restart. USER-VISUAL-CONFIRMATION required for ActionMenu rendering, hover states, recording row swap, and physical key bindings.


### 2026-08-21T23:09:40-07:00: Batch 5 governance correction — ActionMenu ownership transferred to Switch
**By:** Fact Checker (final approval), Switch (ownership), Morpheus (design lead)
**Violation:** Ralph (Work Monitor) wrote ActionMenu.qml and applied implementation bugs directly, violating role boundaries.
**Remediation:** Switch independently reviewed, corrected Escape dismiss (FocusScope approach), and accepted ownership. Fact Checker fresh independent review APPROVED generation 212 artifact /nix/store/arqaib11zrdx0vfn49yp83iqpkh5ar82-quickshell-plate-xiv.
**Policy:** Ralph is a coordinator only. Writing or editing product files (QML, Nix, scripts) requires the correct role owner.


### 2026-08-21T23:35:00-07:00: Architecture cleanup slice closed — generation 213
**By:** Fact Checker, Switch, Tank, Morpheus
**What:** Two bounded behavior-preserving fixes. (1) ControlCenter all action→status-read repoll paths are now visibility-gated (Switch partial, Tank completion after Switch lockout). (2) plate-record-toggle stop branch now uses poll loop for non-child PID, matching plate-record-stop. Three proposed items rejected as churn. Runtime verified on generation 213.
**Why:** The ControlCenter hidden-lifecycle leak was real (process continuations after hide). The record-toggle wait bug was real (non-child PID, early IPC fire). All other proposals were smaller than their cognitive overhead.
**Lockout events:** Switch locked out of ControlCenter.qml Fix 1 revision after FC rejection; Tank revised instead.
