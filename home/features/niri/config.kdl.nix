# Plate XIV niri KDL configuration generator.
#
# Produces a config.kdl string consumed by the niri HM module's
# `wayland.windowManager.niri.extraConfig`.  This file is a pure
# function: it takes the plate token set and the immutable wallpaper
# store path and returns KDL text.  It does NOT set any NixOS/HM
# options itself.
#
# Verified against niri v26.04 (github.com/niri-wm/niri/tree/v26.04)
# using resources/default-config.kdl as the authoritative action reference
# (fetched from the locked nixpkgs niri.src, `nix build --no-link
# nixpkgs#niri.src`, at /nix/store/.../resources/default-config.kdl) plus
# `niri msg action --help` / `niri msg --help` run against the built
# nixpkgs#niri 26.04 binary (D20/D24 empirical verification).
#
# Launcher / Control Center IPC binds (D10/D22/D23) were verified against
# the locally-built nixpkgs#quickshell 0.3.0 `qs`/`quickshell` binary's
# `--help` output. The D10 draft order (`qs ipc call -c <name> ...`) is
# WRONG: `-c` is an option of the `ipc` subcommand, not of `call` —
# confirmed empirically:
#   `qs ipc call -c plate-xiv launcher toggle` -> CLI11 rejects `-c`
#   ("The following argument was not expected: -c")
#   `qs ipc -c plate-xiv call launcher toggle` -> parses correctly,
#   reaches instance lookup ("No running instances for ...").
# The corrected order (`qs ipc -c plate-xiv call <target> toggle`) is used
# below for both the "launcher" and "controlCenter" IPC targets; see the
# trinity-niri-batch2-* inbox note for the D10 correction record.
#
# Token API: home/features/theme/plate.nix (D1/D4 corrected contract).
# Wallpaper path: asahiPaths.wallpaper — immutable store path (D6).
#
# Activation: home/features/niri/default.nix sets
#   wayland.windowManager.niri.extraConfig =
#     (import ./config.kdl.nix) { inherit plate wallpaper; };
# with enable = true (D20 — landed).

{ plate, wallpaper }:

let
  # Column preset widths as decimal proportions — KDL does not parse "1/3"
  # as a number; use the same values as the v26.04 default config.
  colThird = "0.33333";
  colHalf = "0.5";
  colTwoThirds = "0.66667";
  colFull = "1.0";

  # plate.geometry.gap is a CSS string e.g. "4px"; strip the unit for KDL.
  gap = builtins.head (builtins.match "([0-9]+)px" plate.geometry.gap);

  # plate.geometry.border is a CSS string e.g. "1px"; strip the unit.
  focusWidth = builtins.head (builtins.match "([0-9]+)px" plate.geometry.border);

  # niri accepts CSS hex colours directly in focus-ring.
  focusBorder = plate.state.focus; # "#e03c28" — vermilion (D1)
  inactiveBorder = plate.line.edge; # "#555555"

in
''
  // ── Input ─────────────────────────────────────────────────────────────────
  input {
    keyboard {
      xkb {
        layout "us"
      }
    }

    touchpad {
      natural-scroll
      tap
    }
  }

  // ── Output ────────────────────────────────────────────────────────────────
  // No generic output block: niri requires connector names (e.g. "eDP-1").
  // Tank adds a named output node when physical output config is known.

  // ── Layout ────────────────────────────────────────────────────────────────
  layout {
    gaps ${gap}

    // Plate XIV column preset widths: ⅓ · ½ · ⅔ · 1
    // Proportions are decimal fractions as required by niri KDL.
    preset-column-widths {
      proportion ${colThird}
      proportion ${colHalf}
      proportion ${colTwoThirds}
      proportion ${colFull}
    }

    default-column-width { proportion ${colHalf}; }

    focus-ring {
      width ${focusWidth}
      active-color "${focusBorder}"
      inactive-color "${inactiveBorder}"
    }

    border {
      off
    }
  }

  // ── Animations ────────────────────────────────────────────────────────────
  // Use only the `slowdown` scalar verified in the v26.04 default config.
  // Per-animation sub-options (spring, duration-ms, curve) are not
  // configured here to avoid guessing at undocumented option names.
  animations {
    slowdown 1.0
  }

  // ── Client-side decorations ───────────────────────────────────────────────
  // Requests clients to omit CSDs; focus-ring/border draw *around* the window.
  prefer-no-csd

  // ── Spawn-at-startup ──────────────────────────────────────────────────────
  // Quickshell: verified binary name is `quickshell` (nixpkgs#quickshell.meta.mainProgram).
  // Session-scoped; cannot leak into the Hyprland session (D8).
  spawn-at-startup "quickshell" "-c" "plate-xiv"
  // Wallpaper: immutable store path supplied via asahiPaths.wallpaper (D5/D6).
  spawn-at-startup "swaybg" "-i" "${wallpaper}" "-m" "fill"
  spawn-at-startup "blueman-applet"
  spawn-at-startup "wl-paste" "--type" "text" "--watch" "cliphist" "store"
  spawn-at-startup "wl-paste" "--type" "image" "--watch" "cliphist" "store"
  spawn-at-startup "lxqt-policykit-agent"
  spawn-at-startup "gnome-keyring-daemon" "--start" "--components=secrets"

  // ── Key bindings — core navigation ────────────────────────────────────────
  // Action names and modifiers verified against v26.04 resources/default-config.kdl.
  // Move-column uses Mod+Ctrl (not Mod+Shift; that is focus-monitor in v26.04).
  // Workspace move uses move-column-to-workspace (canonical in v26.04).
  // Key names are uppercase as required by niri's XKB key name parsing.
  binds {
    Mod+H     { focus-column-left; }
    Mod+L     { focus-column-right; }
    Mod+J     { focus-window-down; }
    Mod+K     { focus-window-up; }

    Mod+Ctrl+H { move-column-left; }
    Mod+Ctrl+L { move-column-right; }
    Mod+Ctrl+J { move-window-down; }
    Mod+Ctrl+K { move-window-up; }

    Mod+1 { focus-workspace 1; }
    Mod+2 { focus-workspace 2; }
    Mod+3 { focus-workspace 3; }
    Mod+4 { focus-workspace 4; }
    Mod+5 { focus-workspace 5; }

    Mod+Ctrl+1 { move-column-to-workspace 1; }
    Mod+Ctrl+2 { move-column-to-workspace 2; }
    Mod+Ctrl+3 { move-column-to-workspace 3; }
    Mod+Ctrl+4 { move-column-to-workspace 4; }
    Mod+Ctrl+5 { move-column-to-workspace 5; }

    Mod+R       { switch-preset-column-width; }
    Mod+F       { maximize-column; }
    Mod+Shift+F { fullscreen-window; }

    Mod+Q       { close-window; }
    Mod+Return  { spawn "ghostty"; }

    // ── Hardware controls — shared Plate helpers ────────────────────────────
    // Keep niri and Hyprland behavior identical by routing every hardware
    // key through the Plate wrappers installed on the session PATH.
    XF86AudioRaiseVolume allow-when-locked=true { spawn "plate-volume-step" "up"; }
    XF86AudioLowerVolume allow-when-locked=true { spawn "plate-volume-step" "down"; }
    XF86AudioMute allow-when-locked=true { spawn "plate-volume-toggle-mute"; }
    XF86MonBrightnessUp allow-when-locked=true { spawn "plate-brightness-step" "up"; }
    XF86MonBrightnessDown allow-when-locked=true { spawn "plate-brightness-step" "down"; }

    // ── Launcher / lock / logout — D22/D24 wrapper contracts ────────────────
    // Launcher: Quickshell's IpcHandler (target "launcher", function
    // "toggle") per D10/D22. Argument order verified empirically against
    // the built nixpkgs#quickshell 0.3.0 `qs` binary (`-c` belongs to the
    // `ipc` subcommand, not to `call` — see file header). Mirrors
    // Hyprland's Mod+Space -> $menu ergonomics (keybindings.nix).
    Mod+Space { spawn "qs" "ipc" "-c" "plate-xiv" "call" "launcher" "toggle"; }

    // Control Center: same Quickshell IPC-toggle family as the launcher
    // above (target "controlCenter", function "toggle" — D23/Switch's
    // ControlCenter.qml). Mod+Shift+Space chosen as the least-collision,
    // most-consistent unused chord: it pairs with Mod+Space (both are
    // Quickshell IPC toggles, Shift marking the companion surface) and
    // does not clash with the Mod+Ctrl (move) or directional
    // Mod+Shift+H/J/K/L (reserved for focus-monitor, v26.04 default
    // config) chord families already established in this file. No other
    // binding in this file uses Space or Shift+Space.
    Mod+Shift+Space { spawn "qs" "ipc" "-c" "plate-xiv" "call" "controlCenter" "toggle"; }

    // Lock: hyprlock is compositor-agnostic (ext-session-lock-v1, D24) and
    // reused as-is under niri — same bind as Hyprland's Mod+Shift+L.
    Mod+Shift+L { spawn "hyprlock"; }

    // Logout: opens the wlogout menu, matching Hyprland's Mod+Escape bind.
    // wlogout's own button actions call Tank's compositor-detection
    // wrappers (plate-dpms-on/off, plate-logout) internally (D24) — niri's
    // bind only needs to launch the menu, not branch on compositor itself.
    Mod+Escape { spawn "wlogout"; }

    Mod+Shift+E { quit; }
  }
''
