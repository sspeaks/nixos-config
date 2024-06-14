{ ... }:
{
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv6.conf.all.forwarding" = false;
  };
  networking = {
    useNetworkd = true;
    useDHCP = false;

    nat.enable = false;
    firewall.enable = false;
    nftables = {
      enable = true;
      ruleset = ''
        table inet filter {
          chain input {
            type filter hook input priority 0; policy drop;

            iifname { "br-lan" } accept comment "Allow local network to access the router"
            iifname "wlan0" ct state { established, related } accept comment "Allow established traffic"
            iifname "wlan0" icmp type { echo-request, destination-unreachable, time-exceeded } counter accept comment "Allow select ICMP"
            iifname "wlan0" counter drop comment "Drop all other unsolicited traffic from wlan0"
            iifname "lo" accept comment "Accept everything from loopback"
          }
          chain forward {
            type filter hook forward priority filter; policy drop;

            iifname { "br-lan" } oifname { "wlan0" } accept comment "Allow trusted LAN to WAN"
            iifname { "wlan0" } oifname { "br-lan" } ct state { established, related } accept comment "Allow established back to LAN"
          }
        }

        table ip nat {
          chain postrouting {
            type nat hook postrouting priority 100; policy accept;
            oifname "wlan0" masquerade
          }
        }
      '';
    };
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
    };
  };
  services.resolved.enable = false;
  services.dnsmasq = {
    enable = true;
    settings = {
      server = [ "8.8.8.8" "1.1.1.1" ];
      domain-needed = true;
      bogus-priv = true;
      no-resolv = true;

      cache-size = 1000;

      dhcp-range = [ "br-lan,192.168.10.50,192.168.10.254,24h" ];
      interface = "br-lan";
      dhcp-host = "192.168.10.1";

      local = "/lan/";
      domain = "lan";
      expand-hosts = true;

      no-hosts = true;
      address = "/nixpi.lan/192.168.10.1";
    };
  };
}
