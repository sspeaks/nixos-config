{ config, pkgs, lib, ... }:

let
  palette = import ../theme/palette.nix;
  mocha = palette.mocha;
in
{
  programs.alacritty = {
    enable = true;
    settings = {
      env = {
        TERM = "xterm-256color";
      };

      window = {
        padding = {
          x = 10;
          y = 10;
        };
        decorations = "full";
        opacity = 0.95;
        blur = true;
        dynamic_title = true;
      };

      scrolling = {
        history = 10000;
        multiplier = 3;
      };

      font = {
        normal = {
          family = palette.fonts.terminal;
          style = "Regular";
        };
        bold = {
          family = palette.fonts.terminal;
          style = "Bold";
        };
        italic = {
          family = palette.fonts.terminal;
          style = "Italic";
        };
        size = 12.0;
      };

      # Catppuccin Mocha theme (sourced from home/features/theme/palette.nix)
      colors = {
        primary = {
          background = mocha.base;
          foreground = mocha.text;
          dim_foreground = mocha.overlay1;
          bright_foreground = mocha.text;
        };

        cursor = {
          text = mocha.base;
          cursor = mocha.rosewater;
        };

        vi_mode_cursor = {
          text = mocha.base;
          cursor = mocha.lavender;
        };

        search = {
          matches = {
            foreground = mocha.base;
            background = mocha.subtext0;
          };
          focused_match = {
            foreground = mocha.base;
            background = mocha.green;
          };
        };

        footer_bar = {
          foreground = mocha.base;
          background = mocha.subtext0;
        };

        hints = {
          start = {
            foreground = mocha.base;
            background = mocha.yellow;
          };
          end = {
            foreground = mocha.base;
            background = mocha.subtext0;
          };
        };

        selection = {
          text = mocha.base;
          background = mocha.rosewater;
        };

        normal = {
          black = mocha.surface1;
          red = mocha.red;
          green = mocha.green;
          yellow = mocha.yellow;
          blue = mocha.blue;
          magenta = mocha.pink;
          cyan = mocha.teal;
          white = mocha.subtext1;
        };

        bright = {
          black = mocha.surface2;
          red = mocha.red;
          green = mocha.green;
          yellow = mocha.yellow;
          blue = mocha.blue;
          magenta = mocha.pink;
          cyan = mocha.teal;
          white = mocha.subtext0;
        };

        dim = {
          black = mocha.surface1;
          red = mocha.red;
          green = mocha.green;
          yellow = mocha.yellow;
          blue = mocha.blue;
          magenta = mocha.pink;
          cyan = mocha.teal;
          white = mocha.subtext1;
        };

        indexed_colors = [
          { index = 16; color = mocha.peach; }
          { index = 17; color = mocha.rosewater; }
        ];
      };

      selection = {
        save_to_clipboard = true;
      };

      cursor = {
        style = {
          shape = "Block";
          blinking = "On";
        };
        blink_interval = 750;
        unfocused_hollow = true;
      };

      keyboard = {
        bindings = [
          # Shift+Enter sends escape then return (useful for some terminal apps)
          { key = "Return"; mods = "Shift"; chars = "\\u001B\\r"; }
          # Ctrl+Shift+C/V for copy/paste
          { key = "C"; mods = "Control|Shift"; action = "Copy"; }
          { key = "V"; mods = "Control|Shift"; action = "Paste"; }
          # Ctrl+Shift+N for new window
          { key = "N"; mods = "Control|Shift"; action = "SpawnNewInstance"; }
          # Increase/decrease font size
          { key = "Plus"; mods = "Control"; action = "IncreaseFontSize"; }
          { key = "Minus"; mods = "Control"; action = "DecreaseFontSize"; }
          { key = "Key0"; mods = "Control"; action = "ResetFontSize"; }
        ];
      };
    };
  };
}
