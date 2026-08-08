{ config, pkgs, lib, ... }:

let
  palette = import ../theme/palette.nix;
  mocha = palette.mocha;
  # Ghostty wants bare hex (no leading #) for scalar color keys.
  hex = palette.stripHash;
in
{
  programs.ghostty = {
    enable = true;
    settings = {
      # Font (see theme/palette.nix `fonts.terminal`).
      font-family = palette.fonts.terminal;
      font-size = 12;
      font-thicken = true;
      adjust-cell-height = "12%";

      # Catppuccin Mocha, sourced from home/features/theme/palette.nix so the
      # terminal re-themes in lockstep with the rest of the desktop.
      background = hex mocha.base;
      foreground = hex mocha.text;
      cursor-color = hex mocha.rosewater;
      cursor-text = hex mocha.base;
      selection-background = hex mocha.surface2;
      selection-foreground = hex mocha.text;
      palette = [
        "0=${mocha.surface1}"
        "1=${mocha.red}"
        "2=${mocha.green}"
        "3=${mocha.yellow}"
        "4=${mocha.blue}"
        "5=${mocha.pink}"
        "6=${mocha.teal}"
        "7=${mocha.subtext1}"
        "8=${mocha.surface2}"
        "9=${mocha.red}"
        "10=${mocha.green}"
        "11=${mocha.yellow}"
        "12=${mocha.blue}"
        "13=${mocha.pink}"
        "14=${mocha.teal}"
        "15=${mocha.subtext0}"
      ];

      # Window: translucent so Hyprland's blur frosts the background, matching
      # the rest of the desktop. Clean tiled look — Hyprland draws the border.
      background-opacity = 0.95;
      window-padding-x = 10;
      window-padding-y = 10;
      window-padding-balance = true;
      window-decoration = false;
      gtk-titlebar = false;

      # Cursor: blinking block, matching the previous Alacritty feel.
      cursor-style = "block";
      cursor-style-blink = true;
      mouse-hide-while-typing = true;

      # Quality-of-life.
      confirm-close-surface = false;
      copy-on-select = "clipboard";
      scrollback-limit = 10000000;

      # Preserve the Alacritty binding: Shift+Enter sends ESC then Return.
      keybind = [
        "shift+enter=text:\\x1b\\r"
      ];
    };
  };
}
