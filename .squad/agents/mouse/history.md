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

📌 Team update (2026-08-08T00:00:00Z): Plate XIV token design frozen with palette.nix compatibility contract — decided by Morpheus
- Token API (_in_ semantic names, _out_ helpers) must survive re-theming. plate.nix design confirmed robust across 18 consumer patterns.
- palette.nix backward-compat contract is strict: breaking old exports breaks Seth's login. Deprecate consumer-by-consumer in later batches, not all-at-once.
- Terminal ANSI colors are content surfaces, not chrome — full 16-color saturation is legitimate when it preserves compiler/diff legibility.
- GTK/Qt/icons/cursor choices now pinned to verifiable package names on aarch64-linux (adw-gtk3, papirus, bibata). Update codenames in future ricing cycles.
📌 Team update (2026-08-08T11:02:14.979-07:00): Batch 3 tokens (D32) + wallpaper R6 geometry (D31) APPROVED. Added lineHairline + stateFocus to Theme.qml (wired to plate.nix, no new hues). Wallpaper oak leaves: Quercus robur spec met (lobes 35.7–38.5%, veins 30°, midrib rotation, leaves 4/5/6 separation). Morpheus visual approval. — decided by Morpheus, Tank, Trinity, Mouse, Fact Checker

📌 Team update (2026-08-08T15:58:16.477-07:00): Mouse's slider queue fixed dropped rapid updates, but Quickshell 0.3 Process restart inside `exited` raced its still-running state. Per reviewer lockout, Tank owned the next revision and deferred queue flush after synchronously clearing local running state. Final controls APPROVED. — decided by Fact Checker, Mouse, Tank
