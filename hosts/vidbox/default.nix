{ pkgs, lib, inputs, config, ... }:
let
  sopsFileLocation = {
    format = "yaml";
    sopsFile = ../../secrets/vidbox.yaml;
  };

  # The proxy's overlay address: the only peer on wg-edge.
  edgeAddress = "10.10.0.4";
in
# Home server (physical i7-8700): video, ai-coaching, the todo-tui daemon on the
  # tailnet, and the fleet controller that runs update-fleet.
  # Register the host's SSH-derived age identity and re-encrypt its secrets first.
{
  imports = [
    ../common/global
    ../common/users/sspeaks
    ../common/users/sspeaks/authorized-keys.nix
    ./hardware-configuration.nix
    ./ai-coaching.nix
    ./todo-tui.nix
    ./fleet-controller.nix
    ../../modules/restic-offsite.nix
    inputs.home-manager.nixosModules.home-manager
    inputs.determinate.nixosModules.default
    inputs.large-video-streamer.nixosModules.vidStreamer
    inputs.ai-coaching-dashboard.nixosModules.aiCoaching
  ];

  # OIDC credentials must match the ai-coaching client registered in Authentik.
  sops.secrets = {
    ai-coaching-oidc-client-secret = sopsFileLocation // {
      owner = "oauth2-proxy";
      group = "oauth2-proxy";
      mode = "0400";
    };
    ai-coaching-oauth2-proxy-cookie-secret = sopsFileLocation // {
      owner = "oauth2-proxy";
      group = "oauth2-proxy";
      mode = "0400";
    };
    ai-coaching-postgresql-evidence-password = sopsFileLocation // {
      owner = "root";
      group = "root";
      mode = "0400";
    };
    ai-coaching-proxy-auth-env = sopsFileLocation // { mode = "0400"; };
    ai-coaching-speakr-env = sopsFileLocation // { mode = "0400"; };
    ai-coaching-evidence-api-env = sopsFileLocation // { mode = "0400"; };
    ai-coaching-evidence-worker-env = sopsFileLocation // { mode = "0400"; };
    ai-coaching-extraction-gateway-env = sopsFileLocation // { mode = "0400"; };
    restic-password = sopsFileLocation // {
      owner = "root";
      group = "root";
      mode = "0400";
    };
    restic-azure-environment = sopsFileLocation // {
      owner = "root";
      group = "root";
      mode = "0400";
    };
    wg-edge-private-key = sopsFileLocation // {
      owner = "root";
      mode = "0400";
    };
  };

  # Preserve the `vid-stream` container and restic password to retain access
  # to the existing backup history. HLS segments are regenerated from recordings.
  services.resticOffsite = {
    enable = true;
    container = "vid-stream";
    paths = [
      "/srv/videos"
      "/var/lib/ai-coaching"
      "/var/lib/vid-streamer"
    ];
    exclude = [
      "/var/lib/vid-streamer/hls"
    ];
    postgresDatabases = [ "evidence" ];
    sqliteDatabases = {
      # SQLite .backup includes WAL state that a plain file copy can miss.
      vid-streamer-app = "/var/lib/vid-streamer/app.db";
      speakr-transcriptions = "/var/lib/ai-coaching/speakr/instance/transcriptions.db";
    };
  };

  # Dial the edge from home; keepalives preserve the NAT mapping.
  # Each host needs a distinct overlay address for the edge's allowedIPs.
  networking.wireguard.enable = true;
  networking.wireguard.interfaces.wg-edge = {
    ips = [ "10.10.0.5/32" ];
    privateKeyFile = config.sops.secrets.wg-edge-private-key.path;
    peers = [
      {
        # proxy
        publicKey = "Sbm2/JkGPNO9LEsrI2oJSHZNIxoOCsf/2l8jwm6AtHM=";
        endpoint = "20.83.103.87:51820";
        # Edge address only, never a route to the home LAN.
        allowedIPs = [ "${edgeAddress}/32" ];
        persistentKeepalive = 25;
      }
    ];
  };

  # The edge proxies streams.sspeaks.net to aiCoaching's Caddy on :8080 and
  # vidplayback.sspeaks.net to vid-streamer on :8081, both over wg-edge.
  systemd.tmpfiles.rules = [
    "z /srv/videos 0750 sspeaks users -"
  ];

  networking.firewall.allowedTCPPorts = [ 8080 ];
  networking.firewall.interfaces.wg-edge.allowedTCPPorts = [ 8081 ];

  # Authentik on the edge is vid-streamer's only login, so the service itself
  # accepts connections only from the edge and localhost. The firewall alone
  # is not enough: tailscaled accepts all tailscale0 traffic before nixos-fw.
  services.vidStreamer = {
    enable = true;
    package = inputs.large-video-streamer.packages.${pkgs.stdenv.hostPlatform.system}.default;
    videoDir = "/srv/videos";
    videoAccessGroup = "users";
    listenAddr = "0.0.0.0:8081";
    noAuth = true;
  };
  systemd.services.vid-streamer.serviceConfig = {
    IPAddressDeny = "any";
    IPAddressAllow = [
      "localhost"
      edgeAddress
    ];
  };

  home-manager.useUserPackages = true;
  home-manager.users.sspeaks = { ... }: {
    imports = [ ../../home/sspeaks-bare.nix ];
  };

  # update-fleet and ./deploy need non-interactive sudo for activation.
  security.sudo.wheelNeedsPassword = false;
  programs.nix-ld.enable = true;

  time.timeZone = "America/Los_Angeles";
}
