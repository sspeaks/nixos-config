{ inputs, lib, config, ... }:
let
  sopsFileLocation = {
    format = "yaml";
    sopsFile = ../../secrets/nixos-azure.yaml;
  };
in
{
  imports = [
    ../nixos-azure
    ./disk-boot.nix
    ../common/global
    ../common/users/sspeaks
    ./pogbot.nix
    inputs.boggle.nixosModules.default
    (import ../../modules/wireguard/default.nix { inherit sopsFileLocation; })
    ../../modules/azure-serial-console.nix
    inputs.determinate.nixosModules.default
  ];

  users.users.sspeaks.hashedPassword = lib.mkForce null;

  # P1.3 Azure lockout guard. Azure offers no physical console and no
  # link-local rescue, so the serial console is the only way back in after a
  # bad sshd/firewall/network change. neededForUsers is required because the
  # hash must exist before user creation runs.
  sops.secrets.serial-rescue-password-hash = sopsFileLocation // {
    neededForUsers = true;
  };

  services.azureSerialConsole = {
    enable = true;
    passwordHashFile = config.sops.secrets.serial-rescue-password-hash.path;
  };

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
