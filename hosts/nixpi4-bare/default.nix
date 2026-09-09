{ inputs, lib, config, ... }:

# Server variant of `nixpi`: same Pi 4, SD card, SSH key and SOPS identity,
# without the travel-router AP, NAT, bridge or full home-manager profile.
# Reboot when switching variants: dhcpcd and systemd-networkd can otherwise
# leave the old br-lan bridge and addresses behind.
{
  imports = [
    ../common/global
    ../common/users/sspeaks
    ../common/users/sspeaks/authorized-keys.nix
    # Share the disk layout and Pi 4 kernel workaround with nixpi.
    ../nixpi/hardware-config.nix
    # Keep Wi-Fi client access without enabling the router's AP.
    ../nixpi/networking/wlan.nix
    inputs.home-manager.nixosModules.home-manager
    inputs.boggle.nixosModules.default
    ./workloads.nix
  ];

  networking = {
    hostName = "nixpi4-bare";
    useDHCP = lib.mkDefault true;
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.sspeaks = { ... }: {
    imports = [ ../../home/sspeaks-bare.nix ];
    programs.starship.settings.hostname.disabled = false;
    home.enableNixpkgsReleaseCheck = false;
  };


  # Dial out so Caddy reaches the workloads without residential port forwarding.
  # allowedIPs contains only edge addresses, never a route to the home LAN.
  sops.secrets.wg-edge-private-key = {
    format = "yaml";
    sopsFile = ../../secrets/nixpi.yaml;
    mode = "0400";
    owner = "root";
  };

  networking.wireguard.enable = true;
  networking.wireguard.interfaces.wg-edge = {
    ips = [ "10.10.0.3/32" ];
    privateKeyFile = config.sops.secrets.wg-edge-private-key.path;
    peers = [
      {
        publicKey = "gTkLAa4pN+STVJDde9wWI4QDi4AFBn/ArTx6ul/PFAU=";
        endpoint = "40.86.75.95:51820";
        allowedIPs = [ "10.10.0.1/32" ];
        persistentKeepalive = 25;
      }
      {
        # Parallel edge tunnels permit DNS-only cutover/rollback.
        publicKey = "Sbm2/JkGPNO9LEsrI2oJSHZNIxoOCsf/2l8jwm6AtHM=";
        endpoint = "20.83.103.87:51820";
        allowedIPs = [ "10.10.0.4/32" ];
        persistentKeepalive = 25;
      }
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  time.timeZone = "America/Los_Angeles";
  nixpkgs.hostPlatform = "aarch64-linux";
}
