{ pkgs, inputs, ... }:
{
  imports = [
    inputs.nixvim.homeModules.nixvim
    ./colorscheme.nix
    ./snacks.nix
    ./dashboard.nix
    ./diffview.nix
    ./lsp.nix
    ./completion.nix
    ./treesitter.nix
    ./ale.nix
    ./mdkite.nix
  ];

  programs.nixvim = {
    enable = true;
    enableMan = false;
    vimAlias = true;
    nixpkgs.useGlobalPackages = true;
    version.enableNixpkgsReleaseCheck = false;
    extraConfigVim = ''
      set mouse=
    '';

    globals.mapleader = ",";

    dependencies = {
      gcc = {
        enable = true;
        package = pkgs.gcc;
      };
    };

    plugins = {
      web-devicons.enable = true;
      comment.enable = true;
    };

    extraPlugins = with pkgs.vimPlugins; [ vim-nix ];
  };
}
