{ inputs, lib, config, ... }:

# Bare-bones sibling of `nixpi`: the same Raspberry Pi 4 (same SD card, same
# SSH host key, therefore the same sops age identity), but without the travel
# router. Build this generation when the Pi is just a headless box sitting on
# somebody else's network:
#
#   sudo nixos-rebuild switch --flake .#nixpi4-bare   # plain server
#   sudo nixos-rebuild switch --flake .#nixpi         # travel router
#
# Reboot after switching in either direction: the two generations use different
# network stacks (scripted dhcpcd here vs. systemd-networkd there), and a live
# switch can leave the old `br-lan` bridge and its addresses behind.
#
# Dropped relative to `nixpi`: hostapd (AP mode), dnsmasq, the nftables NAT
# ruleset, the systemd-networkd bridge/WireGuard setup, the router helper
# scripts, and the full home-manager profile. Kept: the user, its SSH keys,
# known Wi-Fi networks, and sshd.
{
  imports = [
    ../common/global
    ../common/users/sspeaks
    ../common/users/sspeaks/authorized-keys.nix
    # Shared with `nixpi` so the SD card's disk layout and the rpi4 kernel
    # workaround only ever live in one place.
    ../nixpi/hardware-config.nix
    # Plain wpa_supplicant client for the same known networks as `nixpi` (no AP
    # mode) so the Pi is still reachable without an Ethernet cable.
    ../nixpi/networking/wlan.nix
    inputs.home-manager.nixosModules.home-manager
    # P3.1 workloads migrated off the Azure `nixos` VM.
    inputs.boggle.nixosModules.default
    ./workloads.nix
  ];

  networking = {
    hostName = "nixpi4-bare";
    # `nixpi` replaces this with systemd-networkd; here stock scripted
    # networking + DHCP on every interface is exactly what we want.
    useDHCP = lib.mkDefault true;
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.sspeaks = { ... }: {
    imports = [ ../../home/sspeaks-bare.nix ];
    programs.starship.settings.hostname.disabled = false;
    home.enableNixpkgsReleaseCheck = false;
  };


  # P2.3 — home-initiated tunnel to the Azure edge.
  #
  # Needed before P3.1: Caddy currently reaches Boggle and pogbot at the Azure
  # VM's public hostname. Once those workloads live here, the edge must be able
  # to reach THIS host -- and it must do so without the home network accepting
  # any inbound connection, hence the outbound-dialled tunnel.
  #
  # allowedIPs is the edge's single overlay address, never a LAN prefix, so the
  # Azure edge cannot route into 192.168.5.0/24.
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
    peers = [{
      publicKey = "gTkLAa4pN+STVJDde9wWI4QDi4AFBn/ArTx6ul/PFAU=";
      endpoint = "40.86.75.95:51820";
      allowedIPs = [ "10.10.0.1/32" ];
      persistentKeepalive = 25;
    }];
  };

  security.sudo.wheelNeedsPassword = false;

  time.timeZone = "America/Los_Angeles";
  nixpkgs.hostPlatform = "aarch64-linux";
}
