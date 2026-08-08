{ config, pkgs, lib, ... }:

let
  palette = import ../theme/palette.nix;
  mocha = palette.mocha;
in
{
  programs.wofi = {
    enable = true;
    settings = {
      show = "drun";
      width = 640;
      height = 480;
      always_parse_args = true;
      show_all = false;
      print_command = true;
      insensitive = true;
      prompt = "Search…";
      image_size = 36;
      columns = 1;
      allow_images = true;
      hide_scroll = true;
      matching = "fuzzy";
      content_halign = "fill";
    };
    style = ''
      window {
        margin: 0px;
        border: 2px solid ${palette.accent};
        border-radius: ${palette.radius.lg};
        background-color: ${palette.cssRgba mocha.base "0.96"};
        font-family: ${palette.fonts.mono};
        font-size: 14px;
      }

      #input {
        padding: 12px;
        margin: 14px;
        border: 1px solid ${palette.surfaces.border};
        border-radius: ${palette.radius.md};
        color: ${mocha.text};
        background-color: ${mocha.surface0};
      }

      #input:focus {
        border: 2px solid ${palette.accent};
      }

      #inner-box {
        margin: 6px;
        border: none;
        background-color: transparent;
      }

      #outer-box {
        margin: 8px;
        border: none;
        background-color: transparent;
      }

      #scroll {
        margin: 0px;
        border: none;
      }

      #text {
        margin: 6px;
        border: none;
        color: ${mocha.text};
      }

      #img {
        margin-right: 8px;
      }

      #entry {
        border-radius: ${palette.radius.md};
        padding: 8px;
        margin: 2px 6px;
      }

      #entry:selected {
        background-color: ${palette.surfaces.accentSoft};
        border-left: 3px solid ${palette.accent};
      }

      #entry:selected #text {
        color: ${palette.accent};
        font-weight: bold;
      }
    '';
  };
}
