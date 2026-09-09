{ pkgs, lib, inputs, config, ... }:
let
  sopsFileLocation = {
    format = "yaml";
    sopsFile = ../../secrets/vidbox.yaml;
  };
in
# Home Hyper-V VM for video and ai-coaching.
  # Provision key-only access before enabling the shared SOPS-backed user.
  # Register the host's SSH-derived age identity and re-encrypt its secrets first.
  # Installers also need the project cache for this flake's Determinate build.
{
  imports = [
    ../common/global
    ../common/users/sspeaks
    ../common/users/sspeaks/authorized-keys.nix
    ./hardware-configuration.nix
    ./ai-coaching.nix
    ../../modules/restic-offsite.nix
    inputs.home-manager.nixosModules.home-manager
    inputs.determinate.nixosModules.default
    inputs.large-video-streamer.nixosModules.vidStreamer
    inputs.ai-coaching-dashboard.nixosModules.aiCoaching
  ];

  # OIDC credentials must match the ai-coaching client registered in Authentik.
  sops.secrets = {
    vid-streamer-login-user = sopsFileLocation // {
      owner = "vid-streamer";
      group = "users";
      mode = "0400";
    };
    vid-streamer-login-pass = sopsFileLocation // {
      owner = "vid-streamer";
      group = "users";
      mode = "0400";
    };
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
        allowedIPs = [ "10.10.0.4/32" ];
        persistentKeepalive = 25;
      }
    ];
  };

  # The edge proxies streams.sspeaks.net to aiCoaching's Caddy on :8080;
  # vid-streamer listens separately on :8081.
  systemd.tmpfiles.rules = [
    "z /srv/videos 0750 sspeaks users -"
  ];

  networking.firewall.allowedTCPPorts = [ 8080 8081 ];

  services.vidStreamer = {
    enable = true;
    package = inputs.large-video-streamer.packages.${pkgs.stdenv.hostPlatform.system}.default;
    videoDir = "/srv/videos";
    videoAccessGroup = "users";
    listenAddr = "0.0.0.0:8081";
    openFirewall = true;
    loginUserFile = config.sops.secrets.vid-streamer-login-user.path;
    loginPassFile = config.sops.secrets.vid-streamer-login-pass.path;
  };

  home-manager.useUserPackages = true;
  home-manager.users.sspeaks = { ... }: {
    imports = [ ../../home/sspeaks-bare.nix ];
  };

  # nixos-anywhere and ./deploy need non-interactive sudo for activation.
  security.sudo.wheelNeedsPassword = false;
  programs.nix-ld.enable = true;

  time.timeZone = "America/Los_Angeles";
}
