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
      gac
      comma
      squad-cli
    ];
    sessionVariables = {
      EDITOR = "vim";
    };
  };
  programs.git.settings.user.name = "Seth Speaks";
  programs.git.settings.user.email = "sspeaks610@gmail.com";
  programs.git.signing.format = null;

  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
}
