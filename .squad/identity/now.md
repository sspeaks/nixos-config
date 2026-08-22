---
updated_at: 2026-08-08T05:46:30Z
focus_area: Plate XIV Batch 1 live-validated, Batch 2 design review ratified (D19-D30), Batch 3 planned (system controls: Wi-Fi/Bluetooth/audio/brightness/battery), Batch 2 implementation in progress
active_issues: []
---

# What We're Focused On

Ricing the NixOS/Hyprland desktop. Team cast from The Matrix: Morpheus (aesthetic lead), Trinity (compositor & motion), Switch (bars/menus), Mouse (color/theming), Tank (typography/terminal/Nix). Mandate: no bias toward the existing config, be opinionated.

## Current Status

**Plate XIV Batch 1 LIVE-VALIDATED AND UNBLOCKED (2026-08-07T20:11–20:33-07:00, confirmed by Morpheus + Fact Checker).** All acceptance criteria met on live hardware. One remediation: SDDM password-cursor color defect discovered via safe test-mode greeter render, fixed and verified across two independent launches. Batch 2 design review RATIFIED (12 decisions, D19–D30, covering niri session registration, launcher, notifications, lock-screen, portal refactoring, Hyprland retirement, file ownership, sequencing, gates, and Seth-decisions). **Batch 2 implementation now in progress.**

**Batch 1 artifacts on feature/plate-xiv-desktop @ 71b476f:**
- Semantic token set (plate.nix) with verified WCAG contrast
- Hyprland config rewritten for square, opaque, blur-free aesthetic (all gates PASS)
- Iosevka typography (correct fontconfig families: Iosevka Nerd Font, IosevkaTerm Nerd Font)
- Ghostty terminal with 16-color ANSI palette (live verified)
- Deterministic plate-grid wallpaper (SVG → PNG via resvg, hermetic; confirmed on aarch64)
- niri compositor config (KDL) and Quickshell bar (QML) — authored, eval-covered, dormant (D8/D12)
- All validation gates PASS (asahi toplevel eval ~5.4s, HM stateVersion, wallpaper build, flake check, format)
- SDDM greeter: config tokens verified exact-match to plate.nix (D6); visual rendering confirmed via safe test-mode (background, font, chrome tokens correct); one defect found and fixed (password cursor color); username/session rendering unproven but deferred to Seth's discretion

**Batch 2 scope — DESIGN REVIEW COMPLETE, IMPLEMENTATION NOW IN PROGRESS:**
- niri session registration (dual-session SDDM picker, Tank + Trinity, D19)
- niri activation module (Trinity, D20)
- Portal refactor to per-desktop routing (Tank, D21)
- Quickshell launcher (Switch, D22)
- Quickshell notifications/control-center (Switch, D23, with unresolved dunst dual-instance technical issue flagged for Tank+Trinity pre-default-flip)
- Lock-screen / idle / DPMS / logout handover via compositor-detection wrapper scripts (Switch visuals D24, Tank+Trinity wrappers D24)
- Token completeness (`state.fail` token, Mouse, D25)
- Token migration for wofi/dunst/wlogout/hyprlock (Switch, D26)
- Hyprland retirement sequencing (Trinity timing, Tank mechanics, D28, gated on live validation + Seth decisions D29)

Validation gates: D30 (build/eval-only, pre-merge); D28 step 2 live validation (empirical session switch, niri launcher/notifications/portals/lock/wrappers operational); D28 step 3 Seth decision + burn-in period before Hyprland removal.

Conservative rollout contract: niri remains opt-in at SDDM greeter through design-review ratification; `defaultSession` stays `"hyprland"` (D19); Hyprland remains default and fully intact/untouched except for D24/D26 re-theming and wrapper integration; no Hyprland retirement/default flip until live niri validation passes AND Seth approves (D28 step 2 + D29).

**Batch 3 PLANNED (2026-08-08T05:46Z):** System controls integration — Wi-Fi toggle, Bluetooth toggle, audio/volume slider + mute, brightness slider, battery status in ControlCenter panel. Placement: ControlCenter only (240px + spacing), Caption remains zero-telemetry. Ownership: Switch (QML), Mouse (tokens), Tank (services), Trinity (review), Morpheus (design/aesthetic). Gate: D28 Step 2 live validation + D29 Seth decision required before implementation starts. Rationale: Seth explicitly requested these controls; D23 deferred them as "not scoped this batch"; they fit naturally into ControlCenter once niri is proven. Sequencing: Design phase starts post-D29; implementation gated on niri live validation. Full plan: `.squad/log/2026-08-08T05-45-00-Morpheus-plate-xiv-batch3-system-controls-plan.md`, formal decision: `.squad/decisions/inbox/morpheus-plate-xiv-batch3-system-controls-plan.md`
