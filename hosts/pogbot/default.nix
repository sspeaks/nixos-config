{ inputs, lib, ... }:
let
  sopsFileLocation = {
    format = "yaml";
    sopsFile = ../../secrets/nixos-azure.yaml;
  };
in
{
  imports = [
    ../nixos-azure
    ../common/global
    ../common/users/sspeaks
    ./pogbot.nix
    inputs.boggle.nixosModules.default
    (import ../../modules/wireguard/default.nix { inherit sopsFileLocation; })
    inputs.determinate.nixosModules.default
  ];

  users.users.sspeaks.hashedPassword = lib.mkForce null;

  myWireguard.enable = true;

  nix.settings.lazy-trees = true;

  services.fail2ban = {
    enable = true;
    maxretry = 3;
    bantime = "1h";
    bantime-increment = {
      enable = true;
      maxtime = "168h";
      overalljails = true;
    };
    ignoreIP = [
      "10.100.0.0/24"
      "127.0.0.0/8"
    ];
  };

  system.autoUpgrade = {
    enable = true;
    operation = "boot";
    flake = "github:sspeaks/nixos-config#pogbot";
    dates = "04:30";
    randomizedDelaySec = "15min";
    allowReboot = false;
  };

  programs.nix-ld.enable = true;
}
