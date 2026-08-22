let
  mocha = {
    rosewater = "#f5e0dc";
    flamingo = "#f2cdcd";
    pink = "#f5c2e7";
    mauve = "#cba6f7";
    red = "#f38ba8";
    maroon = "#eba0ac";
    peach = "#fab387";
    yellow = "#f9e2af";
    green = "#a6e3a1";
    teal = "#94e2d5";
    sky = "#89dceb";
    sapphire = "#74c7ec";
    blue = "#89b4fa";
    lavender = "#b4befe";
    text = "#cdd6f4";
    subtext1 = "#bac2de";
    subtext0 = "#a6adc8";
    overlay2 = "#9399b2";
    overlay1 = "#7f849c";
    overlay0 = "#6c7086";
    surface2 = "#585b70";
    surface1 = "#45475a";
    surface0 = "#313244";
    base = "#1e1e2e";
    mantle = "#181825";
    crust = "#11111b";
  };

  fonts = {
    mono = "JetBrainsMono Nerd Font";
    monoCss = ''"JetBrainsMono Nerd Font", "JetBrains Mono Nerd Font", "JetBrains Mono", "Symbols Nerd Font", "Font Awesome 6 Free", monospace'';
    # Cascadia Code (ligature variant) — ligatures render in Ghostty.
    terminal = "CaskaydiaCove Nerd Font";
    sddm = "JetBrains Mono";
  };

  stripHash = color: builtins.substring 1 6 color;

  # Hyprland-style rgba: an 8-digit hex packed inside rgba(), e.g. rgba(89b4faee).
  # Used by hyprland/config.nix and hyprlock. NOT valid CSS.
  rgba = color: alpha: "rgba(${stripHash color}${alpha})";
  rgb = color: "rgb(${stripHash color})";

  # CSS helpers: turn a "#rrggbb" hex into standard CSS rgb()/rgba(r, g, b, a).
  # Used by GTK/CSS consumers (waybar, wofi, wlogout).
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

  # Single accent knob. Change these two lines to re-theme the whole desktop.
  accent = mocha.blue;
  accentAlt = mocha.mauve;

  # Shared corner-radius scale so every surface rounds consistently.
  radius = {
    sm = "6px";
    md = "10px";
    lg = "15px";
    xl = "20px";
  };

  # Semantic, ready-to-drop-in CSS surfaces derived from the palette above.
  # Blur is enabled on these layers, so translucency reads cleanly.
  surfaces = {
    bar = cssRgba mocha.crust "0.85"; # top-level bar / menu window background
    panel = cssRgba mocha.base "0.6"; # individual modules / grouped chips
    island = cssRgba mocha.base "0.7"; # floating waybar pills (frosted islands)
    tooltip = cssRgba mocha.crust "0.95";
    border = cssRgba mocha.surface1 "0.5"; # hairline outline on chips
    shadow = cssRgba mocha.crust "0.45"; # soft drop shadow under chips
    accentSoft = cssRgba accent "0.2"; # hover wash
    accentActive = cssRgba accent "0.3"; # active/selected wash
    urgentSoft = cssRgba mocha.red "0.3";
  };
in
{
  inherit
    mocha
    fonts
    stripHash
    rgba
    rgb
    toRgb
    cssRgb
    cssRgba
    accent
    accentAlt
    radius
    surfaces
    ;

  # Plate XIV semantic token foundation — import for role-based access.
  plate = import ./plate.nix;
}
