# Plate XIV niri KDL configuration generator.
#
# Produces a config.kdl string consumed by the niri HM module's
# `wayland.windowManager.niri.extraConfig`.  This file is a pure
# function: it takes the plate token set and the immutable wallpaper
# store path and returns KDL text.  It does NOT set any NixOS/HM
# options itself.
#
# Verified against niri v26.04 (github.com/niri-wm/niri/tree/v26.04)
# using resources/default-config.kdl as the authoritative action reference.
#
# Token API: home/features/theme/plate.nix (D1/D4 corrected contract).
# Wallpaper path: asahiPaths.wallpaper — immutable store path (D6).
#
# Activation path:
#   In home/features/niri/default.nix, set
#     wayland.windowManager.niri.extraConfig =
#       (import ./config.kdl.nix) { inherit plate wallpaper; };
#   and flip wayland.windowManager.niri.enable = true; when ready.

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

    Mod+Shift+E { quit; }
  }
''
