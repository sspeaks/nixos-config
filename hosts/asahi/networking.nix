{ config, pkgs, lib, ... }:
let
  enableWireguard = false;
in

{
  # WireGuard VPN with kill switch
  sops.secrets.wireguard-private-key = lib.mkIf enableWireguard {
    sopsFile = ../../secrets/asahi.yaml;
  };

  networking.wg-quick.interfaces.wg0 = lib.mkIf enableWireguard {
    address = [ "10.100.0.3/24" ];
    dns = [ "1.1.1.1" ];
    privateKeyFile = config.sops.secrets.wireguard-private-key.path;

    # Kill switch: only allow traffic through WireGuard
    postUp = ''
      ${pkgs.iptables}/bin/iptables -I OUTPUT ! -o wg0 -m mark ! --mark $(${pkgs.wireguard-tools}/bin/wg show wg0 fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
      ${pkgs.iptables}/bin/ip6tables -I OUTPUT ! -o wg0 -m mark ! --mark $(${pkgs.wireguard-tools}/bin/wg show wg0 fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
    '';
    preDown = ''
      ${pkgs.iptables}/bin/iptables -D OUTPUT ! -o wg0 -m mark ! --mark $(${pkgs.wireguard-tools}/bin/wg show wg0 fwmark) -m addrtype ! --dst-type LOCAL -j REJECT || true
      ${pkgs.iptables}/bin/ip6tables -D OUTPUT ! -o wg0 -m mark ! --mark $(${pkgs.wireguard-tools}/bin/wg show wg0 fwmark) -m addrtype ! --dst-type LOCAL -j REJECT || true
    '';

    peers = [
      {
        publicKey = "vq/1shvvFP1lTc7TjdAhIJDEz7hh1Bijv5QwlJz4ND0=";
        allowedIPs = [ "0.0.0.0/0" "::/0" ];
        endpoint = "13.91.123.214:51820";
        persistentKeepalive = 25;
      }
    ];
  };

  networking = {
    hostName = "asahi-mpb";
    firewall.enable = true;
    firewall.allowedUDPPorts = [ 5353 ];
  };

  networking.wireless.iwd = {
    enable = true;
    settings.General.EnableNetworkConfiguration = true;
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };

  environment.systemPackages = lib.optionals enableWireguard [
    pkgs.wireguard-tools
  ];
}
