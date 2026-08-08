# Plate XIV — Semantic Token Foundation
#
# Role-based design tokens for the Plate XIV palette.
# Pure attrset: no imports, no side effects, no pkgs dependency.
# Consumers reference tokens by role, not by raw hex.
# Ratified: D1, D2, D4 — Morpheus design review 2026-08-08.

let
  # ---------------------------------------------------------------------------
  # Color utility helpers (internal — also re-exported below per D4)
  # ---------------------------------------------------------------------------
  stripHash = color: builtins.substring 1 6 color;

  # Hyprland/hyprlock format: "rgba(rrggbbAA)" — alpha is 2 uppercase hex digits.
  hyprRgba = color: alpha: "rgba(${stripHash color}${alpha})";
  hyprRgb = color: "rgb(${stripHash color})";

  hexDigit = c: {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    "a" = 10;
    "b" = 11;
    "c" = 12;
    "d" = 13;
    "e" = 14;
    "f" = 15;
    "A" = 10;
    "B" = 11;
    "C" = 12;
    "D" = 13;
    "E" = 14;
    "F" = 15;
  }.${c};
  hexPair = h: idx:
    (hexDigit (builtins.substring idx 1 h)) * 16
    + (hexDigit (builtins.substring (idx + 1) 1 h));
  toRgb = color:
    let h = stripHash color;
    in "${toString (hexPair h 0)}, ${toString (hexPair h 2)}, ${toString (hexPair h 4)}";
  cssRgb = color: "rgb(${toRgb color})";
  cssRgba = color: alpha: "rgba(${toRgb color}, ${alpha})";

in
{
  # ── Semantic groups ────────────────────────────────────────────────────────

  # Background layers — darkest to lightest (D1)
  bg = {
    void = "#0a0a0a"; # true black; wallpaper / deepest layer
    plate = "#111111"; # primary surface (bars, menus)
    panel = "#1a1a1a"; # elevated surface (tooltips, popups)
    inset = "#232323"; # interactive fill (inputs, hover)
  };

  # Structural lines (D1)
  line = {
    hairline = "#2e2e2e"; # subtle separator / divider (wallpaper grid fine)
    rule = "#404040"; # visible separator (wallpaper grid coarse)
    edge = "#555555"; # visible border / outline (inactive)
  };

  # Foreground text hierarchy (D1)
  fg = {
    muted = "#5a5a5a"; # disabled, placeholders (intentionally sub-AA)
    secondary = "#909090"; # captions, subtext (AA)
    primary = "#d4d4d4"; # body text, labels (AAA)
  };

  # Accent — vermilion is the ONLY non-neutral hue (D1)
  accent = {
    vermilion = "#e03c28"; # primary brand / focus / urgent (AA on bg.plate)
    on = "#ffffff"; # text on vermilion surfaces
  };

  # Semantic state colors (D1)
  state = {
    focus = "#e03c28"; # focused / active element highlight (= vermilion)
    urgent = "#e03c28"; # urgent notification (= vermilion)
    warn = "#a0a0a0"; # warning / modified state
    ok = "#6e6e6e"; # success / ok state
    inactive = "#333333"; # inactive / disabled element
  };

  # Layout geometry — string values per D1 (CSS-compatible units)
  geometry = {
    radius = "0px"; # corner rounding — sharp edges, Plate XIV style
    border = "1px"; # default border width
    gap = "4px"; # inner gap between tiled windows
    gapOuter = "8px"; # outer gap / margin to screen edge
  };

  # Typography — fontconfig family strings (D2)
  type = {
    mono = "Iosevka Nerd Font"; # general monospace / code
    terminal = "IosevkaTerm Nerd Font"; # terminal emulator
    sddm = "Iosevka Nerd Font"; # login screen (SDDM/QML)
    monoCss = ''"Iosevka Nerd Font", "Symbols Nerd Font", monospace''; # CSS font-family stack

    # Size scale — CSS-compatible strings (D1)
    size = {
      xs = "11px";
      sm = "12px";
      md = "13px";
      lg = "15px";
      xl = "18px";
    };
  };

  # ── Emit-format helpers (D4) ──────────────────────────────────────────────
  # Exact surface: stripHash, toRgb, hyprRgba, hyprRgb, cssRgb, cssRgba.
  # Bare hex IS the token value; identity passthroughs are rejected.
  inherit stripHash toRgb hyprRgba hyprRgb cssRgb cssRgba;
}
