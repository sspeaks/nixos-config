# Plate XIV role-based design tokens; no pkgs dependency.
# Consumers reference tokens by role, not by raw hex.

let
  stripHash = color: builtins.substring 1 6 color;

  # Hyprland/hyprlock use packed hex rgba(rrggbbaa), not CSS rgba(r, g, b, a).
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
  # Background layers — darkest to lightest
  bg = {
    void = "#0a0a0a"; # wallpaper / deepest layer
    plate = "#111111"; # primary surface (bars, menus)
    panel = "#1a1a1a"; # elevated surface (tooltips, popups)
    inset = "#232323"; # interactive fill (inputs, hover)
  };

  # Structural lines
  line = {
    hairline = "#2e2e2e"; # subtle separator / divider (wallpaper grid fine)
    rule = "#404040"; # visible separator (wallpaper grid coarse)
    edge = "#555555"; # visible border / outline (inactive)
  };

  # Foreground text hierarchy
  fg = {
    muted = "#5a5a5a"; # disabled, placeholders (intentionally sub-AA)
    secondary = "#909090"; # captions, subtext (AA)
    primary = "#d4d4d4"; # body text, labels (AAA)
  };

  # Vermilion is the only non-neutral hue.
  accent = {
    vermilion = "#e03c28"; # primary brand / focus / urgent
    on = "#ffffff"; # text on vermilion surfaces
  };

  # Semantic state colors
  state = {
    focus = "#e03c28"; # focused / active element highlight (= vermilion)
    urgent = "#e03c28"; # urgent notification (= vermilion)
    warn = "#a0a0a0"; # warning / modified state
    ok = "#6e6e6e"; # success / ok state
    inactive = "#333333"; # inactive / disabled element
    fail = "#e03c28"; # failure / error state
  };

  # Geometry uses CSS strings; numeric consumers must strip the units.
  geometry = {
    radius = "0px"; # corner rounding — sharp edges, Plate XIV style
    border = "1px"; # default border width
    gap = "4px"; # inner gap between tiled windows
    gapOuter = "8px"; # outer gap / margin to screen edge
  };

  # Typography — fontconfig family strings
  type = {
    mono = "Iosevka Nerd Font"; # general monospace / code
    terminal = "IosevkaTerm Nerd Font"; # terminal emulator
    sddm = "Iosevka Nerd Font"; # login screen (SDDM/QML)
    monoCss = ''"Iosevka Nerd Font", "Symbols Nerd Font", monospace''; # CSS font-family stack

    # CSS size scale
    size = {
      xs = "11px";
      sm = "12px";
      md = "13px";
      lg = "15px";
      xl = "18px";
    };
  };

  # Tokens are bare hex; these helpers emit compositor or CSS formats.
  inherit stripHash toRgb hyprRgba hyprRgb cssRgb cssRgba;
}
