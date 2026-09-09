{ lib, config, ... }:
# Public edge: WireGuard ingress, Caddy vhosts, and the static-content publisher.
let
  sopsFileLocation = {
    format = "yaml";
    sopsFile = ../../secrets/proxy.yaml;
  };

  # Use staging for ACME rehearsals, production for browser-trusted certificates.
  # Before moving an edge, build in CI, prefetch the closure, and point DNS here
  # before activation starts production ACME challenges.
  useStagingACME = false;

  # Symlinks below preserve the pipelines' /usr/share/caddy{,2,3} upload paths.
  webroots = {
    "sspeaks.net" = "/var/www/sspeaks.net";
    "mycatsonfire.com" = "/var/www/mycatsonfire.com";
    "chordplay.sspeaks.net" = "/var/www/chordplay";
  };
in
{
  sops.secrets.proxy-wg-private-key = sopsFileLocation;
  sops.secrets.serial-rescue-password-hash = sopsFileLocation // {
    neededForUsers = true;
  };

  # Override the locked bootstrap fallback with the SOPS-provided rescue hash.
  services.azureSerialConsole.passwordHashFile =
    lib.mkForce config.sops.secrets.serial-rescue-password-hash.path;

  # Home hosts dial out, so the edge needs no residential IP address.
  networking.wireguard.enable = true;
  networking.wireguard.interfaces.wg-edge = {
    # Keep a distinct overlay address from the .1 edge: peers cannot share
    # allowedIPs, and parallel tunnels allow DNS-only cutover and rollback.
    ips = [ "10.10.0.4/32" ];
    listenPort = 51820;
    privateKeyFile = config.sops.secrets.proxy-wg-private-key.path;
    peers = [
      {
        # nixpi5 — Authentik, Home Assistant
        publicKey = "CGbdDbPaUhkWR7bwwxixBNGbI7/fxA9Hf2gSKB4Y6R0=";
        allowedIPs = [ "10.10.0.2/32" ];
      }
      {
        # nixpi4-bare — pogbot, boggle
        publicKey = "i6lFAchjSAx0zohEa2mm/qJ4JGL36HYXuQqNsQ3Jk38=";
        allowedIPs = [ "10.10.0.3/32" ];
      }
      {
        # vidbox — video and ai-coaching
        publicKey = "jTa6Da0QXwj7tg9nE2MM99CYIl6AufCztXCwTTR11x8=";
        allowedIPs = [ "10.10.0.5/32" ];
      }
    ];
  };

  # Azure Pipelines publishes static content over SSH as this key-only user.
  # Preserve the account, keys, and upload paths when moving the edge.
  users.groups.devops.gid = 1001;
  users.users.devops = {
    isNormalUser = true;
    uid = 1001;
    group = "devops";
    extraGroups = [ "caddy" ];
    home = "/home/devops";
    createHome = true;
    hashedPassword = "!";
    openssh.authorizedKeys.keyFiles = [ ./devops-authorized-keys ];
  };

  systemd.tmpfiles.rules = [
    "d /var/www 0755 root root -"
    "d ${webroots."sspeaks.net"} 2775 devops caddy -"
    "d ${webroots."mycatsonfire.com"} 2775 devops caddy -"
    "d ${webroots."chordplay.sspeaks.net"} 2775 devops caddy -"

    "d /usr/share 0755 root root -"
    "L+ /usr/share/caddy - - - - ${webroots."sspeaks.net"}"
    "L+ /usr/share/caddy2 - - - - ${webroots."mycatsonfire.com"}"
    "L+ /usr/share/caddy3 - - - - ${webroots."chordplay.sspeaks.net"}"
  ];

  services.caddy = {
    enable = true;
    acmeCA = lib.mkIf useStagingACME
      "https://acme-staging-v02.api.letsencrypt.org/directory";

    # Bound per-vhost logs to protect the small root filesystem.
    virtualHosts = lib.mapAttrs
      (host: vhost: vhost // {
        logFormat = ''
          output file /var/log/caddy/access-${host}.log {
            roll_size 10MiB
            roll_keep 3
          }
          level ERROR
        '';
      })
      {
        # Reach vidbox over the private overlay, not a public backend address.
        "streams.sspeaks.net".extraConfig = ''
          reverse_proxy 10.10.0.5:8080
        '';

        "auth.sspeaks.net".extraConfig = ''
          reverse_proxy 10.10.0.2:9000
        '';

        "home-assistant.sspeaks.net".extraConfig = ''
          tls {
            client_auth {
              mode require_and_verify
              trusted_ca_cert_file ${./myCA.pem}
            }
          }
          reverse_proxy 10.10.0.2:8123 {
            header_up Host home-assistant.sspeaks.net
          }
        '';

        "bootstrap.sspeaks.net".extraConfig = ''
          redir https://raw.githubusercontent.com/sspeaks/nixos-config/main/scripts/bootstrap.sh 302
        '';

        "mycatsonfire.com".extraConfig = ''
          root * ${webroots."mycatsonfire.com"}
          file_server

          reverse_proxy /pogbot {
            to http://10.10.0.3:8080
            header_up X-Requested-With {doesntmatter}
          }
          handle_path /pogbot/* {
            reverse_proxy http://10.10.0.3:8080
          }
        '';

        "chordplay.sspeaks.net".extraConfig = ''
          encode zstd gzip
          root * ${webroots."chordplay.sspeaks.net"}
          file_server
        '';

        # Boggle uses a same-origin URL; strip its prefix and proxy directly.
        "sspeaks.net".extraConfig = ''
          encode zstd gzip
          root * ${webroots."sspeaks.net"}
          file_server

          handle_path /boggle/* {
            reverse_proxy 10.10.0.3:8081
          }
        '';
      };
  };
}
