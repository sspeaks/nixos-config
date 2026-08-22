# Project Context

- **Owner:** Seth Speaks
- **Project:** nixos-config — a personal NixOS "ricing" setup (flakes + home-manager) centered on a Hyprland Wayland desktop. Compositor config lives in `home/features/hyprland/` (config.nix, theme.nix, keybindings.nix, packages.nix, startup.nix, lock-idle.nix). Current look is Catppuccin Mocha; hyprlock/hypridle in use. Note: hyprpaper is disabled (crashes on Asahi) — swaybg is used for wallpaper.
- **Stack:** Nix, NixOS, home-manager, flakes; Hyprland (Wayland); waybar, wofi, dunst, wlogout, hyprlock; starship; ghostty, alacritty; Nerd Fonts.
- **Created:** 2026-08-07T18:23:40-07:00

## Team Ethos (applies to me and every member)

1. **No bias toward the existing config.** The current stack (incl. Hyprland) has no special standing — evaluate compositor, motion, and effects on merit against real alternatives (sway, river, niri).
2. **Be particularly opinionated.** Take a clear, defensible position on motion and ergonomics. Strong opinions, loosely held.
3. **Cohesion over collection.** Motion is part of one designed system, not an isolated tweak.

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->
- Hyprpaper crashes on Asahi Linux (null monitor description); the repo uses swaybg instead. Keep this in mind for any wallpaper/compositor work.

📌 Team update (2026-08-08T00:00:00Z): Hyprland & niri config pattern established — decided by Morpheus
- Hyprland config sourcing ALL values from palette helpers (no inlined hex) proved effective — all consumers updated atomically.
- Immutable wallpaper path in store (from Tank's refactor) broke wallpaper-refresh systemd services; caught and remediated per D6.
- niri config authored in KDL with spawn-at-startup for cross-compositor launching. Verify `qs ipc` flag order with `qs ipc --help` on live run (D10 contingency).
- Compositor-agnostic modules (auto-brightness.nix) can stay unchanged across Hyprland → niri transition. Tag these explicitly for later phases.
- Startup sequence must account for both Hyprland mutable-path and niri immutable-path wallpaper. Keep wallpaper wiring agnostic of store/mutable distinction.
📌 Team update (2026-08-08T11:02:14.979-07:00): Batch 3 session integration (D33) APPROVED. Hyprland restored to sessionPackages. UPower daemon enabled. All 6 Fact Checker corrections applied to ControlCenter. Layer-shell audit complete (no compositor changes needed for visible-only polling). Greeter fallback + niri default verified. — decided by Morpheus, Tank, Trinity, Mouse, Fact Checker

📌 Team update (2026-08-08T15:58:16.477-07:00): niri and Hyprland now share identical XF86 volume and brightness bindings, with brightness user intent persisted through an XDG runtime baseline. Hyprland remains the safe fallback. Live hardware/session validation remains. — decided by Trinity, Tank, Morpheus
