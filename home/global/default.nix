{ lib, pkgs, config, outputs, options, ... }:
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
  nixpkgs = lib.mkIf (options.nixpkgs ? config) {
    overlays = outputs.overlays;
    config = {
      allowUnfree = true;
    };
  };

  home = {
    username = lib.mkDefault "sspeaks";
    homeDirectory = lib.mkDefault (
      (if pkgs.stdenv.hostPlatform.system == "aarch64-darwin" then "/Users/" else "/home/") +
      "${config.home.username}"
    );
    stateVersion = lib.mkDefault "23.05";
  };

  systemd.user.services.nix-gc-user = {
    Unit.Description = "Nix user profile garbage collection";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.nix}/bin/nix-collect-garbage --delete-older-than 14d";
    };
  };
  systemd.user.timers.nix-gc-user = {
    Unit.Description = "Nix user profile garbage collection timer";
    Timer = {
      OnCalendar = "weekly";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
