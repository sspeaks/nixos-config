# Asahi Configuration Improvements Design

## Problem

The Asahi NixOS configuration has several high-value stability, visual, and maintainability improvements documented in `~/how-can-i-improve-this-asahi-configuration-to-be-m.md`. The changes should improve reliability and polish while preserving familiar physical key chords unless explicitly approved otherwise.

## Approved scope

Implement the full staged comprehensive change set:

- Remove duplicate daemon startup paths for `dunst` and `hypridle`.
- Cap retained systemd-boot generations.
- Make iwd the owner of network configuration by disabling global NixOS DHCP.
- Make XDG portal routing explicit for Hyprland screen sharing and GTK file choosing.
- Coordinate auto-brightness with Hypridle dimming.
- Make brightness commands target `apple-panel-bl`.
- Apply Catppuccin Mocha visual polish across Hyprland, Hyprlock, Waybar, Dunst, and SDDM.
- Centralize shared palette/font values and wallpaper path.
- Split the Hyprland home-manager module into focused modules, with keybindings isolated.
- Guard or move WSL-only zsh aliases so they do not leak into Asahi.
- Disable/remove the wlogout hibernate action because this host has no persistent swap configured for hibernation.

## Key decisions

Physical key chords should remain stable. Command-only improvements inside keybinding entries are allowed when they keep the same physical keys. The only approved key-behavior removal is the wlogout hibernate menu action.

iwd should own wireless network configuration on this Asahi host, so the implementation will set `networking.useDHCP = false` rather than waiting for a per-interface DHCP decision.

The implementation should use a staged approach rather than a big-bang refactor. Shared constants and structural seams should be added first, then stability and visual changes should be applied through those seams.

## Architecture

The Hyprland feature should become a small entrypoint that imports focused modules:

- `theme.nix` for GTK, Qt, cursor, and Hyprland theme-related settings.
- `config.nix` for compositor, monitor, input, window, animation, and layer-rule settings.
- `keybindings.nix` for Hyprland physical key chords.
- `startup.nix` for `exec-once` startup programs.
- `lock-idle.nix` for Hyprlock and Hypridle.
- `packages.nix` for user packages and helper wrappers.
- `kde.nix` for KDE/Dolphin support files.
- Existing `auto-brightness.nix` remains separate.

Theme constants should be centralized in a shared home feature module or imported value file so Catppuccin colors, fonts, and CSS font stacks are defined once. The wallpaper path should also be centralized and reused by the Bing wallpaper service, SDDM, and Hyprland startup.

## Stability design

`dunst` and `hypridle` should be removed from Hyprland `exec-once`; their Home Manager services should remain enabled as the single startup owners.

`boot.loader.systemd-boot.configurationLimit = 5` should be added beside the existing systemd-boot options.

XDG portals should include both `xdg-desktop-portal-hyprland` and `xdg-desktop-portal-gtk`, with common routing that prefers Hyprland for screencast/screenshot and GTK for file chooser.

Hypridle dimming should create a sentinel file under `$XDG_RUNTIME_DIR` before dimming and remove it on resume. The auto-brightness loop should skip screen brightness writes while the sentinel exists, while still allowing keyboard backlight updates.

Brightness commands in Hyprland keybindings, Hypridle, and Waybar should explicitly use `brightnessctl -d apple-panel-bl`.

## Visual design

Hyprland active borders should use Catppuccin Mocha blue and mauve; inactive borders should use Mocha overlay colors. Layer rules should enable blur for Dunst and Waybar.

Hyprlock should retain the blurred screenshot background and input field, add clock/user labels, and align input-field colors with Mocha text/base/surface values.

Waybar's `#window` module should use the same padding, margin, translucent background, and rounded pill style as the other modules.

Dunst should use modest transparency and a rounded progress bar to match the translucent desktop style.

SDDM should reuse the shared wallpaper path and set Catppuccin accent/font values when supported by the theme override.

Subjective polish should be limited to the low-risk recommendations from the review after theme centralization, avoiding workflow changes beyond the explicitly approved hibernate removal.

## Validation

Use existing repository tooling only:

- Run `nix fmt`.
- Run `nix flake check`.
- Build `.#nixosConfigurations.asahi.config.system.build.toplevel` with `nom build` if available, otherwise with `nix build`.
- Inspect the final diff to confirm physical key chords are preserved except for the approved hibernate removal and command-only brightness improvements.

## Non-goals

Do not change `system.stateVersion`.

Do not replace the `nixos-apple-silicon` firmware or sound base.

Do not introduce unrelated refactors outside the files touched by the documented Asahi improvements.
