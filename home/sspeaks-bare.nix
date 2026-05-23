{ config, pkgs, ... }:
{

  imports = [
    ./global
    features/git
    features/zsh
  ];
  nix.settings.builders-use-substitutes = true;
  home = {
    packages = with pkgs; [
      git
      vim
      htop
    ];
    sessionVariables = {
      EDITOR = "vim";
    };
  };
  programs.git.settings.user.name = "Seth Speaks";
  programs.git.settings.user.email = "sspeaks610@gmail.com";
  programs.git.signing.format = null;
}
