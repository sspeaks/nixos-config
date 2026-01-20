{ config, pkgs, ... }:

let
  ls-colors = pkgs.callPackage features/ls-colors.nix { };
in
{

  imports = [
    ./global
    features/git
    features/starship
    features/zsh
  ];
  nix.settings.trusted-users = [ "root" "sspeaks" ];
  home = {
    packages = with pkgs; [
      ls-colors
      ripgrep
      git
      starship
      htop
      shellcheck
      direnv
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
