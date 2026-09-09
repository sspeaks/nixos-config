# Generate KDL for default.nix from theme/plate.nix tokens and the host's
# immutable wallpaper path; this function sets no module options.
# Action reference: https://github.com/niri-wm/niri/blob/v26.04/resources/default-config.kdl

{ plate, wallpaper }:

let
  # Column preset widths as decimal proportions — KDL does not parse "1/3"
  # as a number; use the same values as the v26.04 default config.
  colThird = "0.33333";
  colHalf = "0.5";
  colTwoThirds = "0.66667";
  colFull = "1.0";

  # Geometry tokens use CSS px strings; KDL requires unitless numbers.
  gap = builtins.head (builtins.match "([0-9]+)px" plate.geometry.gap);
  focusWidth = builtins.head (builtins.match "([0-9]+)px" plate.geometry.border);

  # niri accepts CSS hex colours directly in focus-ring.
  focusBorder = plate.state.focus;
  inactiveBorder = plate.line.edge;

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

  // ── Layout ────────────────────────────────────────────────────────────────
  layout {
    gaps ${gap}

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
  animations {
    slowdown 1.0
  }

  // ── Client-side decorations ───────────────────────────────────────────────
  // Requests clients to omit CSDs; focus-ring/border draw *around* the window.
  prefer-no-csd

  // ── Spawn-at-startup ──────────────────────────────────────────────────────
  // Start Quickshell only in this session, not in the Hyprland fallback.
  spawn-at-startup "quickshell" "-c" "plate-xiv"
  spawn-at-startup "swaybg" "-i" "${wallpaper}" "-m" "fill"
  spawn-at-startup "blueman-applet"
  spawn-at-startup "wl-paste" "--type" "text" "--watch" "cliphist" "store"
  spawn-at-startup "wl-paste" "--type" "image" "--watch" "cliphist" "store"
  spawn-at-startup "lxqt-policykit-agent"
  spawn-at-startup "gnome-keyring-daemon" "--start" "--components=secrets"

  // ── Key bindings — core navigation ────────────────────────────────────────
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
    // Share hardware-key behavior with Hyprland through the Plate helpers.
    XF86AudioRaiseVolume allow-when-locked=true { spawn "plate-volume-step" "up"; }
    XF86AudioLowerVolume allow-when-locked=true { spawn "plate-volume-step" "down"; }
    XF86AudioMute allow-when-locked=true { spawn "plate-volume-toggle-mute"; }
    XF86MonBrightnessUp allow-when-locked=true { spawn "plate-brightness-step" "up"; }
    XF86MonBrightnessDown allow-when-locked=true { spawn "plate-brightness-step" "down"; }

    // ── Launcher / lock / logout ──────────────────────────────────────────
    // Quickshell requires `qs ipc -c <config> call <target> <function>`:
    // -c belongs to ipc and must precede call.
    Mod+Space { spawn "qs" "ipc" "-c" "plate-xiv" "call" "launcher" "toggle"; }

    Mod+Shift+Space { spawn "qs" "ipc" "-c" "plate-xiv" "call" "controlCenter" "toggle"; }

    // hyprlock uses ext-session-lock-v1 and works in both compositors.
    Mod+Shift+L { spawn "hyprlock"; }

    // ActionMenu's logout entry opens wlogout.
    Mod+Escape { spawn "qs" "ipc" "-c" "plate-xiv" "call" "actionMenu" "toggle"; }

    Mod+Shift+R { spawn "plate-record-toggle"; }

    // ── Clipboard / capture / night-light ─────────────────────────────────
    // Apple keyboard (no Print key): Mod+Shift+P = screenshot, Mod+Shift+O = OCR.
    // External keyboard: Print = screenshot, Mod+Shift+Print = OCR.
    Mod+C { spawn "sh" "-c" "cliphist list | wofi --dmenu | cliphist decode | wl-copy"; }
    Print           { spawn "plate-screenshot"; }
    Mod+Shift+P     { spawn "plate-screenshot"; }
    Mod+Shift+Print { spawn "plate-ocr"; }
    Mod+Shift+O     { spawn "plate-ocr"; }
    Mod+N { spawn "plate-nightlight-toggle"; }

    Mod+Shift+E { quit; }
  }
''
