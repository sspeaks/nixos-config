{ pkgs, inputs, ... }:
{
  imports = [ inputs.nixvim.homeManagerModules.nixvim ];

  programs.nixvim = {
    enable = true;
    vimAlias = true;
    extraConfigVim = ''
      set mouse=
    '';

    globals.mapleader = ",";
    plugins = {
      telescope = {
        enable = true;
        keymaps = {
          "<leader>ff" = "find_files";
          "<leader>gf" = "git_files";
          "<leader>fg" = "live_grep";
        };
      };
    };
    extraPlugins = with pkgs.vimPlugins; [ ale vim-nix ];
  };
}
