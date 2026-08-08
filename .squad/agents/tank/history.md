# Project Context

- **Owner:** Seth Speaks
- **Project:** nixos-config — a personal NixOS "ricing" setup built with flakes + home-manager. Modular `home/features/` layout (each feature is a `default.nix`): fonts, ghostty, alacritty, tmux, starship, zsh, neovim, hyprland, theme, wofi, dunst, wlogout, etc. Flake is split into `flake-modules/` (hosts, home, packages, devshell, treefmt, git-hooks). Fonts: JetBrainsMono Nerd Font (mono), CaskaydiaMono Nerd Font (terminal), with a documented CSS fallback chain in `palette.nix`. treefmt + pre-commit hooks enforce formatting. hyprpaper disabled (Asahi crash) → swaybg for wallpaper.
- **Stack:** Nix, NixOS, home-manager, flakes, flake-parts-style `flake-modules/`; Hyprland (Wayland); ghostty, alacritty, tmux, zsh, starship, neovim; Nerd Fonts; treefmt + git-hooks/pre-commit.
- **Created:** 2026-08-07T18:23:40-07:00

## Team Ethos (applies to me and every member)

1. **No bias toward the existing config.** Current fonts/terminal/prompt/module layout have no special standing — evaluate alternatives (Iosevka/Berkeley Mono; kitty/foot; restructured modules) on merit for the design direction and reproducibility.
2. **Be particularly opinionated.** Take a clear position on typography and module structure. Strong opinions, loosely held.
3. **Cohesion over collection.** Terminal/prompt/fonts derive from shared tokens (Mouse's palette, one type scale) — no private colorschemes.

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->
- Repo enforces formatting via treefmt + pre-commit/git-hooks — run/format before proposing Nix changes so hooks don't reject them.
- `home/features/` is already cleanly modular (one `default.nix` per feature); preserve that composability when adding or restructuring ricing features.
