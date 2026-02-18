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
  # nix.settings.trusted-public-keys = [
  #   "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
  #   "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
  # ];
  # nix.settings.substituters = [
  #   "https://cache.nixos.org"
  #   "https://cache.iog.io"
  # ];
  nix.settings.builders-use-substitutes = true;
  home = {
    packages = with pkgs; [
      ls-colors
      ripgrep
      bat
      git
      starship
      xclip
      htop
      shellcheck
      direnv
      myCopilot
      ralph
      gac
      # cabal-install
      # haskell-language-server
    ];
    sessionVariables = {
      EDITOR = "vim";
    };
  };
  programs.git.settings.user.name = "Seth Speaks";
  programs.git.settings.user.email = "sspeaks610@gmail.com";

  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
}
