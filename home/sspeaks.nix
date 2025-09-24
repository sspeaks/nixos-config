{ config, pkgs, ... }:

let
  ls-colors = pkgs.callPackage features/ls-colors.nix { };
in
{

  imports = [
    ./global
    features/git
    features/tmux
    features/neovim
    features/starship
    features/zsh
  ];
  nix.settings.trusted-users = [ "root" "sspeaks" ];
  nix.settings.builders-use-substitutes = true;
  home = {
    packages = with pkgs; [
      ls-colors
      ripgrep
      git
      starship
      xclip
      htop
      shellcheck
      direnv
      ghc
      cabal-install
      haskell-language-server
      garnet
    ];
    sessionVariables = {
      EDITOR = "vim";
    };
  };
  programs.git.userName = "Seth Speaks";
  programs.git.userEmail = "sspeaks610@gmail.com";

  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
}
