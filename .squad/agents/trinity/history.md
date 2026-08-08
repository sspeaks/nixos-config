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
