{ config, lib, pkgs, ... }:
let
  enableWireguard = false;
  wgFwMark = 4242;
  wgTable = 4000;
in
{

  environment.systemPackages = lib.mkIf enableWireguard [
    pkgs.wireguard-tools
  ];
  sops.secrets.wireguard-private-key = {
    format = "yaml";
    sopsFile = ../secrets.yaml;
    group = "systemd-network";
    mode = "0440";
    path = "/wireguardKeys/wireguard-private-key";
  };
  systemd.tmpfiles.rules = [
    "d /wireguardKeys/ 0550 root systemd-network"
  ];

  networking = {
    useNetworkd = true;
    useDHCP = false;
  };
  systemd.network = {
    wait-online.anyInterface = true;
    netdevs = {
      "20-br-lan" = {
        netdevConfig = {
          Kind = "bridge";
          Name = "br-lan";
        };
      };

      "10-wg0" = lib.mkIf enableWireguard {
        netdevConfig = {
          Kind = "wireguard";
          Name = "wg0";
          MTUBytes = "1300";
        };
        wireguardConfig = {
          PrivateKeyFile = config.sops.secrets.wireguard-private-key.path;
          ListenPort = 9918;
          FirewallMark = wgFwMark;
          RouteTable = "off";
        };
        wireguardPeers = [
          {
            wireguardPeerConfig = {
              PublicKey = "vq/1shvvFP1lTc7TjdAhIJDEz7hh1Bijv5QwlJz4ND0="; # server public key
              AllowedIPs = [ "0.0.0.0/0" ];
              Endpoint = "13.91.123.214:51820";
              RouteTable = "off";
            };
          }
        ];
      };
    };
    networks = {
      "30-lan0" = {
        matchConfig.Name = "end0";
        linkConfig.RequiredForOnline = "enslaved";
        networkConfig = {
          Bridge = "br-lan";
          ConfigureWithoutCarrier = true;
        };
      };
      "40-br-lan" = {
        matchConfig.Name = "br-lan";
        bridgeConfig = { };
        address = [
          "192.168.10.1/24"
        ];
        networkConfig = {
          ConfigureWithoutCarrier = true;
        };
      };

      "10-wan" = {
        matchConfig.Name = "wlan0";
        networkConfig = {
          # start a DHCP Client for IPv4 Addressing/Routing
          DHCP = "ipv4";
          DNSOverTLS = true;
          DNSSEC = true;
          IPv6PrivacyExtensions = false;
          IPForward = true;
        };
        # make routing on this interface a dependency for network-online.target
        linkConfig.RequiredForOnline = "routable";
      };

      "10-wg0" = lib.mkIf enableWireguard {
        matchConfig.Name = "wg0";
        address = [ "10.100.0.3/24" ];
        #        gateway = [
        #         "10.100.0.1"
        #      ];
        routingPolicyRules = [
          {
            routingPolicyRuleConfig = {
              Family = "both";
              Table = "main";
              SuppressPrefixLength = 0;
              Priority = 10;
            };
          }
          {
            routingPolicyRuleConfig = {
              Family = "both";
              InvertRule = true;
              FirewallMark = wgFwMark;
              Table = wgTable;
              Priority = 11;
            };
          }
        ];
        routes = [
          {
            routeConfig = {
              Destination = "0.0.0.0/0";
              Table = wgTable;
              Scope = "link";
            };
          }
        ];
        linkConfig.RequiredForOnline = false;

      };
    };
  };
  services.irqbalance.enable = false;
}
