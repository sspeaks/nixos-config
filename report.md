# Verification & Constraint Report: Applying Omarchy Patterns to NixOS Asahi

## 1. What Omarchy Actually Ships Today
- **Base Environment:** An opinionated Arch Linux setup driven by a suite of bash scripts (`omarchy-*`) and `pacman` manifests.
- **Desktop UI:** A tightly integrated Qt/QML shell environment using **Quickshell** for the top bar, menu, notifications, OSD, and lock screen.
- **Compositor Config:** A highly modularized **Lua** configuration for Hyprland.
- **Theming:** A template system (`default/themed/*.tpl`) paired with **Aether** (a 3rd-party color extraction tool) to inject wallpaper-derived palettes into terminals, editors, and the shell.

## 2. Project-Native Behavior vs. Custom Workarounds
- **Hyprland Lua Configuration (Native):** Hyprland natively introduced Lua configuration support in v0.55. Omarchy leverages this built-in capability (`hl.config()`) rather than utilizing a custom transpiler or fork.
- **Dotfile Management (Custom Assumption):** Omarchy completely relies on a custom `omarchy-refresh-config` script and GNU `stow` behavior, demanding a mutable `~/.config` state rather than declarative system definitions.

## 3. Portability Hazards on NixOS & Apple Silicon (Asahi)
- **Apple Silicon Wi-Fi Breakage (High Confidence):** Omarchy's `install/hardware/apple/fix-brcmfmac-supplicant.sh` writes `options brcmfmac feature_disable=0x82000` to modprobe. As confirmed by upstream [Issue #7439](https://github.com/basecamp/omarchy/issues/7439), this targets Intel Macs but actively blocks Wi-Fi association on Apple Silicon (M1/M2 BCM4378/BCM4387 chips).
- **Initramfs / Boot Failure (High Confidence):** Omarchy heavily modifies system hooks using Arch's `mkinitcpio`. Its `omarchy_hooks.conf` drops critical hooks by explicitly replacing the entire array (see [Issue #6876](https://github.com/basecamp/omarchy/issues/6876)). Blindly adopting this logic would bypass NixOS's native initrd generation and the `nixos-apple-silicon` early-boot firmware injection, rendering the host unbootable.
- **Package & State Mutability (High Confidence):** The vast `omarchy-*` CLI suite assumes the presence of `pacman`/AUR and a writable root/config filesystem, fundamentally clashing with NixOS immutability and Home Manager's read-only store structure.

## 4. Evaluation of Borrowing Major Patterns
- **Quickshell for UI Integration**
  - *Context:* The Asahi host already contains dormant "Plate XIV" Quickshell infrastructure (`hosts/asahi/desktop.nix`).
  - *Verdict:* **Safe to Endorse**. Borrowing Omarchy's QML component design (e.g., OSD or lock screen) is highly valuable. Quickshell components are OS-agnostic and map cleanly to any Wayland compositor (including `niri`).
- **Aether for Dynamic Theming**
  - *Context:* The Asahi host currently uses a static theme (`plate.nix`).
  - *Verdict:* **Requires Experiments**. Aether excels at color extraction, but wrapping it to regenerate templates within Nix is complex. Native declarative tools like `stylix` or `nix-colors` are inherently safer. If adopted, Aether should remain a runtime user-space utility rather than a build-time dependency.
- **Lua for Hyprland**
  - *Context:* The Asahi host's primary session is now `niri` (Batch 3 gate); Hyprland is maintained solely as a fallback.
  - *Verdict:* **Reject**. Porting Hyprland's configuration to Lua would introduce maintenance overhead with negligible UX return, given the pivot to Niri (configured via KDL).
- **Omarchy CLI & Hardware Scripts**
  - *Context:* Omarchy scripts rely on x86_64 and pacman assumptions.
  - *Verdict:* **Reject**. NixOS's `nixos-apple-silicon` flake perfectly encapsulates Asahi hardware quirks. Porting Omarchy's scripts would degrade stability and introduce catastrophic regressions (e.g., the Broadcom Wi-Fi breakage).

## Final Recommendations
1. **Adopt** Omarchy's Quickshell architectural patterns to accelerate the dormant Plate XIV UI build.
2. **Experiment** with Aether exclusively as an imperative, user-level theme generator.
3. **Reject** all Omarchy hardware scripts, boot tweaks, and the Hyprland Lua migration effort for this host.
