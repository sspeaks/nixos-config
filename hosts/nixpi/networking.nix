{ pkgs, ... }:
# See https://github.com/ghostbuster91/nixos-router for inspiration
{
  imports = [
    ./networking/dnsmasq.nix
    ./networking/nftables.nix
    ./networking/hostapd.nix
    ./networking/wlan.nix
    ./networking/networkd.nix
  ];

  environment.systemPackages = with pkgs; [
    wpa_supplicant
    tcpdump
    midori
    (callPackage ./networking/scripts/get_networks.nix { })
    (callPackage ./networking/scripts/toggle_wireguard.nix { })
  ];
}
