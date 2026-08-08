# Project Context

- **Owner:** Seth Speaks
- **Project:** nixos-config — a personal NixOS "ricing" setup (flakes + home-manager) on a Hyprland Wayland desktop. Persistent chrome currently: waybar (status bar), wofi (launcher), dunst (notifications), wlogout (power menu), hyprlock (lockscreen). Styling consumes shared CSS surfaces/tokens exposed from `home/features/theme/palette.nix` (bar/panel/island/tooltip/border/shadow + radius scale).
- **Stack:** Nix, NixOS, home-manager, flakes; Hyprland (Wayland); waybar, wofi, dunst, wlogout, hyprlock; starship; ghostty, alacritty; Nerd Fonts.
- **Created:** 2026-08-07T18:23:40-07:00

## Team Ethos (applies to me and every member)

1. **No bias toward the existing config.** waybar/wofi/dunst have no special standing — pick bar/launcher/notification tools on merit (eww, ags/Astal, rofi, mako, swaync) per the design language.
2. **Be particularly opinionated.** Take a clear position on information density and interaction feel. Strong opinions, loosely held.
3. **Cohesion over collection.** Consume Mouse's color/radius tokens; never invent one-off hex values. Every surface shares one shape language.

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->
- `palette.nix` already exposes ready-to-use CSS surfaces (`surfaces.bar/panel/island/tooltip/border/shadow/accentSoft/...`) and a `radius` scale — consume these instead of hardcoding colors or corner radii.
