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
        # NO ENDPOINT. The server this used to dial was the `nixos` Azure VM at
        # 13.91.123.214, deleted 2026-09-04 in P3.3. Azure has taken that Basic
        # public IP back into its pool, so it can be reassigned to an unrelated
        # tenant; leaving the literal here would mean anyone flipping
        # enableWireguard to true would start sending handshakes to a stranger.
        #
        # The VM was not running WireGuard by the end anyway: its NixOS config
        # had networking.wireguard.enable = false and defined no interfaces. The
        # UDP 51820 rule in nixosNSG was a leftover from the earlier imperative
        # setup, alongside the Minecraft and Dynmap rules.
        #
        # Set a new endpoint here before re-enabling this tunnel.
        persistentKeepalive = 25;
      }
    ];
  };

  networking = {
    hostName = "asahi-mpb";
    useDHCP = false;
    firewall.enable = true;
    firewall.allowedUDPPorts = [ 5353 ];
  };

  networking.wireless.iwd = {
    enable = true;
    settings = {
      General.EnableNetworkConfiguration = true;
      Network.NameResolvingService = "resolvconf";
    };
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };

  environment.systemPackages = lib.optionals enableWireguard [
    pkgs.wireguard-tools
  ];
}
