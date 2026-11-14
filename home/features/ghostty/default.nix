{ config, pkgs, lib, ... }:

let
  plate = import ../theme/plate.nix;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
in
{
  programs.ghostty = {
    enable = true;
    # nixpkgs' source-built ghostty is Linux-only; ghostty-bin is the official macOS app bundle.
    package = if isDarwin then pkgs.ghostty-bin else pkgs.ghostty;
    settings = {
      font-family = plate.type.terminal;
      font-size = 14;
      adjust-cell-height = "12%";

      background = plate.stripHash plate.bg.void;
      # Slightly brighter than plate.fg.primary: body text in a terminal reads dim at d4d4d4.
      foreground = "e6e6e6";
      cursor-color = plate.stripHash plate.accent.vermilion;
      cursor-text = plate.stripHash plate.bg.void;
      selection-background = plate.stripHash plate.line.rule;
      selection-foreground = "ffffff";

      # Vermilion stays the red; the other hues are vivid enough to read at a glance
      # but keep a slightly warm, muted-pastel cast so they sit well on the void background.
      palette = [
        "0=1c1c1c" # black    — visible against the void background
        "1=e03c28" # red      — vermilion
        "2=7fbf6a" # green
        "3=e0b44c" # yellow
        "4=5a9ae0" # blue
        "5=c27ad6" # magenta
        "6=4cc2c2" # cyan
        "7=c8c8c8" # white
        "8=6a6a6a" # br-black — comments / dim text, still legible
        "9=ff5a44" # br-red
        "10=9ad98a" # br-green
        "11=f2cc6b" # br-yellow
        "12=7fb4f0" # br-blue
        "13=d99aea" # br-magenta
        "14=7ad9d9" # br-cyan
        "15=f5f5f5" # br-white
      ];

      window-padding-x = 16;
      window-padding-y = 12;
      window-padding-balance = true;
      window-padding-color = "extend";

      background-opacity = 1.0;
      cursor-style = "bar";
      cursor-style-blink = false;
      mouse-hide-while-typing = true;

      unfocused-split-opacity = 0.85;
      split-divider-color = plate.stripHash plate.line.rule;

      confirm-close-surface = false;
      copy-on-select = "clipboard";
      scrollback-limit = 10000000;

      keybind = [
        "shift+enter=text:\\x1b\\r"
      ];
    } // lib.optionalAttrs isDarwin {
      # Tabs live in the titlebar, which is painted with the terminal background.
      macos-titlebar-style = "tabs";
      # Iosevka is a light face; thickening plus linear blending gives crisper, brighter text on Retina.
      font-thicken = true;
      alpha-blending = "linear-corrected";
      macos-option-as-alt = "left";
      window-save-state = "always";
      window-width = 120;
      window-height = 34;
      # Plate-themed dock icon: vermilion ghost on a void screen.
      macos-icon = "custom-style";
      macos-icon-frame = "chrome";
      macos-icon-ghost-color = plate.stripHash plate.accent.vermilion;
      macos-icon-screen-color = "${plate.stripHash plate.bg.void},${plate.stripHash plate.bg.inset}";
    } // lib.optionalAttrs (!isDarwin) {
      window-decoration = false;
      gtk-titlebar = false;
    };
  };
}
