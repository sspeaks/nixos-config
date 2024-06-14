{...}:
{

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
