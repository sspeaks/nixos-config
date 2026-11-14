{ pkgs, ... }:
let
  # snacks centers each header line on its own, so pad them to one width
  padLines = text:
    let
      lines = pkgs.lib.splitString "\n" text;
      width = pkgs.lib.foldl' (acc: l: pkgs.lib.max acc (builtins.stringLength l)) 0 lines;
    in
    pkgs.lib.concatMapStringsSep "\n"
      (l: l + pkgs.lib.strings.replicate (width - builtins.stringLength l) " ")
      lines;
in
{
  programs.nixvim.plugins.snacks.settings.dashboard = {
    enabled = true;
    # no '' pairs in the art: they would end the Nix string.
    # Only the rocket is padded: padLines counts bytes, and each
    # one-word motto line centers correctly on its own anyway.
    preset.header = padLines ''
             _
           .' '.
          /     \
         |       |
         |       |
         |_______|
         |       |
         |=======|
        /|       |\
         |   N   |
         |   E   |
         |   W   |
         |       |
         |   G   |
         |   L   |
         |   E   |
         |   N   |
         |   N   |
        ||       ||
       /||_______||\
       / /ooooooo\ \
      /_/ \:::::/ \_\
           \:::/
            \:/
             V'' + "\n\n" + ''
      █▀▀ █▀█ ▄▀█ █▀▄ ▄▀█ ▀█▀ █ █▀▄▀█
      █▄█ █▀▄ █▀█ █▄▀ █▀█  █  █ █ ▀ █

      █▀▀ █▀▀ █▀█ █▀█ █▀▀ █ ▀█▀ █▀▀ █▀█
      █▀  ██▄ █▀▄ █▄█ █▄▄ █  █  ██▄ █▀▄'';
    preset.keys = [
      { icon = " "; key = "f"; desc = "Find File"; action.__raw = "function() Snacks.picker.files() end"; }
      { icon = " "; key = "g"; desc = "Grep"; action.__raw = "function() Snacks.picker.grep() end"; }
      { icon = " "; key = "r"; desc = "Recent Files"; action.__raw = "function() Snacks.picker.recent() end"; }
      { icon = " "; key = "e"; desc = "Explorer"; action.__raw = "function() Snacks.explorer() end"; }
      { icon = " "; key = "l"; desc = "Lazygit"; action.__raw = "function() Snacks.lazygit() end"; }
      { icon = " "; key = "q"; desc = "Quit"; action = ":qa"; }
    ];
    # The default "startup" section requires lazy.nvim
    sections = [
      { section = "header"; }
      { section = "keys"; gap = 1; padding = 1; }
    ];
  };
}
