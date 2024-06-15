{ pkgs, ... }:
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
  ];
}
