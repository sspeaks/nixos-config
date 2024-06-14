{...}:
{

  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv6.conf.all.forwarding" = false;
  };
  networking = {
    nat.enable = false;
    firewall.enable = false;
nftables = {
      enable = true;
      ruleset = ''
        table inet filter {
          chain input {
            type filter hook input priority 0; policy drop;

            iifname { "br-lan" } accept comment "Allow local network to access the router"
            #iifname "wlan0" ct state { established, related } accept comment "Allow established traffic"
            iifname "wlan0" accept comment "meant for use in home network to allow ssh"
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
}
