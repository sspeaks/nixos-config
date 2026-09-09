{ sopsFileLocation }: { pkgs, lib, config, ... }: {
  options.myWireguard.enable = lib.mkEnableOption "enable my local wireguard";
  config = lib.mkIf config.myWireguard.enable {
    networking.nat.enable = true;
    networking.nat.externalInterface = "eth0";
    networking.nat.internalInterfaces = [ "wg0" ];
    networking.firewall = {
      allowedUDPPorts = [ 51820 ];
    };
    networking.wireguard.enable = true;
    networking.wireguard.useNetworkd = false;

    sops.secrets = {
      wireguard-public-key = sopsFileLocation;
      wireguard-private-key = sopsFileLocation;
    };

    networking.wireguard.interfaces = {
      wg0 = {
        ips = [ "10.100.0.1/24" ];

        listenPort = 51820;

        # Clients using this internet gateway must also configure a DNS server.
        postSetup = ''
          ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 10.100.0.0/24 -o eth0 -j MASQUERADE
        '';

        postShutdown = ''
          ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 10.100.0.0/24 -o eth0 -j MASQUERADE
        '';

        # An inline privateKey would expose the secret in the Nix store.
        privateKeyFile = config.sops.secrets.wireguard-private-key.path;

        peers = [
          {
            publicKey = "O8TZmgIYbb07OS4VTV+3GkXhHaYOI3Ccbod4DaUuHwQ=";
            allowedIPs = [ "10.100.0.2/32" ];
          }
          # Nixpi
          {
            publicKey = "uB527Y0lyfRQTYtYF0zJeqxrAti+6Z2JAtg/8PujrUw=";
            allowedIPs = [ "10.100.0.3/32" ];
          }
          # Home PC
          {
            publicKey = "jj/PlPfdyY1kakJVTlI1IcLDqf/eHMRymjH/IxCtpVE=";
            allowedIPs = [ "10.100.0.10/32" ];
          }
          {
            publicKey = "K6MUfPZN15FTizIpcgADLfEc6PuIvyROpHdTAGx0NBw=";
            allowedIPs = [ "10.100.0.11/32" ];
          }
          {
            publicKey = "DawvQxIlWShCYWGBwH+pWUKfkQTV953wNINM9fH7yyQ=";
            allowedIPs = [ "10.100.0.12/32" ];

          }
        ];
      };
    };
  };
}
