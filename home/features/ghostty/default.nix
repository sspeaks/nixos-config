{ config, pkgs, lib, ... }:

let
  plate = import ../theme/plate.nix;
in
{
  programs.ghostty = {
    enable = true;
    settings = {
      font-family = plate.type.terminal;
      font-size = 14;
      adjust-cell-height = "12%";

      background = plate.stripHash plate.bg.void;
      foreground = plate.stripHash plate.fg.primary;
      cursor-color = plate.stripHash plate.accent.vermilion;
      cursor-text = plate.stripHash plate.bg.void;
      selection-background = plate.stripHash plate.bg.inset;
      selection-foreground = plate.stripHash plate.fg.primary;

      # D15 — ratified 16-colour ANSI table.
      palette = [
        "0=111111" # black    — plate surface
        "1=c23b2a" # red      — vermilion dark
        "2=4a7c4e" # green    — desaturated
        "3=8a7540" # yellow   — desaturated
        "4=3d5a78" # blue     — desaturated
        "5=6e4e6e" # magenta  — desaturated
        "6=3d6e6e" # cyan     — desaturated
        "7=909090" # white    — fg.secondary
        "8=3d3d3d" # br-black — raised surface
        "9=e03c28" # br-red   — vermilion
        "10=6aa672" # br-green — desaturated
        "11=b89c54" # br-yel   — desaturated
        "12=5580a8" # br-blue  — desaturated
        "13=9a6e9a" # br-mag   — desaturated
        "14=52a0a0" # br-cyan  — desaturated
        "15=d4d4d4" # br-white — fg.primary
      ];

      window-padding-x = 12;
      window-padding-y = 10;
      window-decoration = false;
      gtk-titlebar = false;

      background-opacity = 1.0;
      cursor-style = "bar";
      cursor-style-blink = false;
      mouse-hide-while-typing = true;

      confirm-close-surface = false;
      copy-on-select = "clipboard";
      scrollback-limit = 10000000;

      keybind = [
        "shift+enter=text:\\x1b\\r"
      ];
    };
  };
}
