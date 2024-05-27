{ config, pkgs, ... }:

let
  ls-colors = pkgs.callPackage features/ls-colors.nix { };
in
{

  imports = [
    ./global
    features/git
    features/neovim
    features/starship
    features/zsh
  ];
  nix.settings.trusted-users = [ "sspeaks" ];
  home = {
    packages = with pkgs; [
      ls-colors
      ripgrep
      git
      starship
      xclip
      htop
      shellcheck
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
