# Project Context

- **Owner:** Seth Speaks
- **Project:** nixos-config — a personal NixOS "ricing" setup (flakes + home-manager) on a Hyprland Wayland desktop. Color already follows a good pattern: `home/features/theme/palette.nix` is the single source of truth — it defines the Catppuccin Mocha ramp, a single `accent`/`accentAlt` knob, a `radius` scale, semantic CSS `surfaces`, and helpers (`rgba`/`rgb` for Hyprland, `cssRgb`/`cssRgba` for GTK/CSS). Theming applied in `home/features/hyprland/theme.nix` (GTK = catppuccin-gtk blue/mocha, icons = Papirus catppuccin, cursor = catppuccin mocha blue, Qt = adwaita-dark via gtk platform theme).
- **Stack:** Nix, NixOS, home-manager, flakes; Hyprland (Wayland); GTK/Qt theming; waybar, wofi, dunst, wlogout, hyprlock; Nerd Fonts.
- **Created:** 2026-08-07T18:23:40-07:00

## Team Ethos (applies to me and every member)

1. **No bias toward the existing config.** Catppuccin Mocha has no special standing — benchmark it against gruvbox, tokyonight, rosé-pine, Nord, and custom palettes for this design direction and switch without sentiment if another wins.
2. **Be particularly opinionated.** Take a clear, contrast-backed position on scheme and accent hierarchy. Strong opinions, loosely held.
3. **Cohesion over collection.** One source of truth for color; every app derives from semantic tokens — no private hex values.

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->
- `palette.nix` is the re-theme knob: change `accent`/`accentAlt` (and the `mocha` ramp) to re-theme the whole desktop. Preserve this single-source-of-truth pattern in any scheme change — swap the ramp, keep the token API.
