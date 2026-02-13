{ config, pkgs, lib, ... }:

{
  programs.wofi = {
    enable = true;
    settings = {
      show = "drun";
      width = 500;
      height = 400;
      always_parse_args = true;
      show_all = false;
      print_command = true;
      insensitive = true;
      prompt = "Search...";
      image_size = 32;
      columns = 1;
      allow_images = true;
      hide_scroll = true;
      matching = "fuzzy";
      content_halign = "fill";
    };
    style = ''
      window {
        margin: 0px;
        border: 2px solid #89b4fa;
        border-radius: 15px;
        background-color: #1e1e2e;
        font-family: "JetBrainsMono Nerd Font";
        font-size: 14px;
      }

      #input {
        padding: 10px;
        margin: 10px;
        border: none;
        border-radius: 10px;
        color: #cdd6f4;
        background-color: #313244;
      }

      #input:focus {
        border: 2px solid #89b4fa;
      }

      #inner-box {
        margin: 5px;
        border: none;
        background-color: transparent;
      }

      #outer-box {
        margin: 5px;
        border: none;
        background-color: transparent;
      }

      #scroll {
        margin: 0px;
        border: none;
      }

      #text {
        margin: 5px;
        border: none;
        color: #cdd6f4;
      }

      #entry {
        border-radius: 10px;
        padding: 5px;
      }

      #entry:selected {
        background-color: #313244;
        border: 2px solid #89b4fa;
      }

      #entry:selected #text {
        color: #89b4fa;
      }
    '';
  };
}
