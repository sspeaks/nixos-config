{ lib, config, ... }:
# P4.1 — everything the replacement edge has to actually serve.
#
# Three concerns live here: the WireGuard listener the home hosts dial into,
# Caddy's public vhosts, and the `devops` account that Azure Pipelines uses to
# publish static content.
let
  sopsFileLocation = {
    format = "yaml";
    sopsFile = ../../secrets/proxy.yaml;
  };

  # Flip to true for the P4.2 Let's Encrypt STAGING rehearsal, then back to
  # false before the real cutover. Staging has effectively no rate limit, so a
  # botched rehearsal cannot burn the production 5-failures-per-hour budget.
  useStagingACME = false;

  # Old edge -> new edge. The pipelines write to the /usr/share names, which do
  # not exist on NixOS; the real roots are these, and compatibility symlinks
  # are created below so no pipeline has to change.
  webroots = {
    "sspeaks.net" = "/var/www/sspeaks.net";
    "mycatsonfire.com" = "/var/www/mycatsonfire.com";
    "chordplay.sspeaks.net" = "/var/www/chordplay";
  };
in
{
  # ------------------------------------------------------------- secrets ---
  sops.secrets.proxy-wg-private-key = sopsFileLocation;
  sops.secrets.serial-rescue-password-hash = sopsFileLocation // {
    neededForUsers = true;
  };

  # The image shipped with the rescue account LOCKED because a freshly built
  # specialized image has no sops identity. The proxy has booted and its host
  # key is now registered in .sops.yaml, so the real hash can be wired up.
  services.azureSerialConsole.passwordHashFile =
    lib.mkForce config.sops.secrets.serial-rescue-password-hash.path;

  # ----------------------------------------------------------- wireguard ---
  # The edge is the LISTENER; both home hosts dial out (P2.3 tunnel
  # inversion). That is what keeps the residential address out of every config
  # on this machine.
  networking.wireguard.enable = true;
  networking.wireguard.interfaces.wg-edge = {
    ips = [ "10.10.0.1/32" ];
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
    ];
  };

  # -------------------------------------------------------- deploy account ---
  # Azure Pipelines (org marialith191, projects sspeaks.net / mycatsonfire /
  # Chordplay) publishes over SSH via CopyFilesOverSSH@0 as this user. The
  # service connections address the host as ssh://sspeaks.net:22, so DNS
  # cutover repoints them automatically -- provided the account, its keys and
  # the target paths all exist here first.
  #
  # Password is LOCKED, exactly as on the old edge: authentication is by key
  # only. sshd already has PasswordAuthentication = false.
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

    # Compatibility shims. The pipelines target /usr/share/caddy{,2,3}; NixOS
    # has no /usr/share at all. Symlinking rather than editing three
    # azure-pipelines.yml files decouples the DNS cutover from three separate
    # repo changes -- deploys keep working whichever lands first.
    "d /usr/share 0755 root root -"
    "L+ /usr/share/caddy - - - - ${webroots."sspeaks.net"}"
    "L+ /usr/share/caddy2 - - - - ${webroots."mycatsonfire.com"}"
    "L+ /usr/share/caddy3 - - - - ${webroots."chordplay.sspeaks.net"}"
  ];

  # --------------------------------------------------------------- caddy ---
  services.caddy = {
    enable = true;
    acmeCA = lib.mkIf useStagingACME
      "https://acme-staging-v02.api.letsencrypt.org/directory";

    virtualHosts = {
      # vid-stream is still the Azure VM until P3.2 moves it home; this becomes
      # a 10.10.0.x overlay address at that point.
      "streams.sspeaks.net".extraConfig = ''
        reverse_proxy 20.236.57.191:8080
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

      # The old edge sent /boggle/* through a Node 10.11.0 cors-anywhere
      # container: it rewrote the path to /http://10.10.0.3:8081/<board> and
      # proxied that to localhost:8080, which re-fetched it. The frontend calls
      # a RELATIVE URL (fetch(`boggle/${board}`)), so it was always same-origin
      # and the CORS hop was a pure forwarder. handle_path strips the prefix
      # and reaches the same backend directly; verified byte-identical
      # (sha256 81c5879f...) against the live path before removal. That
      # retires an EOL-since-2019 Node runtime from the public edge.
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
