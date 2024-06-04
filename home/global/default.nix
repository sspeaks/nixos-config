{ lib, pkgs, config, ... }:
{
  nix = {
    package = lib.mkDefault pkgs.nix;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      warn-dirty = false;
    };
  };

  programs = {
    home-manager.enable = true;
    git.enable = true;
  };
  home = {
    username = lib.mkDefault "sspeaks";
    homeDirectory = lib.mkDefault (
      (if pkgs.system == "aarch64-darwin" then "/Users/" else "/home/") +
      "${config.home.username}"
    );
    stateVersion = lib.mkDefault "23.05";
  };
}
