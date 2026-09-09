# Omarchy ideas for the Asahi desktop

Research notes, not a deployment guide. Review upstream versions and hardware
assumptions before adopting a feature.

## Repository context

- [Asahi desktop configuration](hosts/asahi/desktop.nix) selects Niri and keeps
  Hyprland available as a fallback.
- [Niri configuration](home/features/niri/config.kdl.nix) starts the Plate XIV
  Quickshell UI.
- [Plate theme tokens](home/features/theme/plate.nix) provide the static palette
  used by the [Quickshell module](home/features/quickshell/default.nix).

## Recommendations

| Idea | Recommendation |
| --- | --- |
| Integrated desktop UI | Evaluate useful interaction patterns for the existing Plate XIV components; check compositor and service requirements before adopting them. |
| Wallpaper-derived palettes, including Aether | Experiment separately. Integrate through declarative configuration or runtime-owned files, not by overwriting Home Manager's store-backed files. |
| Hyprland Lua migration | Defer: Niri is the primary session, so a fallback-compositor migration adds maintenance without addressing the main desktop. |
| Arch package and dotfile scripts | Do not copy directly. Express dependencies and managed configuration through NixOS and Home Manager. |
| Hardware and boot tweaks | Keep NixOS/Asahi integration authoritative. Review each change against Apple Silicon hardware and NixOS initrd generation. |

## Upstream references to review

[Omarchy issue #7439](https://github.com/basecamp/omarchy/issues/7439) and
[issue #6876](https://github.com/basecamp/omarchy/issues/6876) are starting points
for hardware and boot research. Check each report's hardware and software
versions before applying its conclusions to this host.
