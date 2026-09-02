{ inputs, lib, config, pkgs, ... }:
let
  sopsFileLocation = {
    format = "yaml";
    sopsFile = ../../secrets/vid-stream.yaml;
  };
in
{
  imports = [
    ../nixos-azure
    ../common/global
    ../common/users/sspeaks
    inputs.large-video-streamer.nixosModules.vidStreamer
    inputs.ai-coaching-dashboard.nixosModules.aiCoaching
    inputs.determinate.nixosModules.default
    ../../modules/restic-offsite.nix
    ../../modules/azure-serial-console.nix
    ./ai-coaching.nix
  ];

  users.users.sspeaks.hashedPassword = lib.mkForce null;

  # P1.3 Azure lockout guard. neededForUsers is required because the hash must
  # exist before user creation runs.
  sops.secrets.serial-rescue-password-hash = sopsFileLocation // {
    neededForUsers = true;
  };

  services.azureSerialConsole = {
    enable = true;
    passwordHashFile = config.sops.secrets.serial-rescue-password-hash.path;
  };

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
    ai-coaching-proxy-auth-env = sopsFileLocation // {
      owner = "root";
      group = "root";
      mode = "0400";
    };
    ai-coaching-speakr-env = sopsFileLocation // {
      owner = "root";
      group = "root";
      mode = "0400";
    };
    ai-coaching-evidence-api-env = sopsFileLocation // {
      owner = "root";
      group = "root";
      mode = "0400";
    };
    ai-coaching-evidence-worker-env = sopsFileLocation // {
      owner = "root";
      group = "root";
      mode = "0400";
    };
    ai-coaching-extraction-gateway-env = sopsFileLocation // {
      owner = "root";
      group = "root";
      mode = "0400";
    };
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
  };

  # P1.2 offsite backup. The mandatory data gate is /srv/videos (32 GB of
  # irreplaceable source recordings) plus /var/lib/ai-coaching (8.4 GB of
  # application state, not disposable derived output).
  #
  # /var/lib/vid-streamer/hls is deliberately EXCLUDED: it is 35 GB of derived
  # HLS segments regenerable from the source recordings. Backing it up would
  # nearly double the repository and add 35 GB to every restore test for no
  # recovery value.
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
      # WAL-mode databases: `.backup` gives a consistent snapshot; a plain file
      # copy would miss the -wal contents and could restore torn state.
      vid-streamer-app = "/var/lib/vid-streamer/app.db";
      speakr-transcriptions = "/var/lib/ai-coaching/speakr/instance/transcriptions.db";
    };
  };

  services.fail2ban = {
    enable = true;
    maxretry = 3;
    bantime = "1h";
    bantime-increment = {
      enable = true;
      maxtime = "168h";
      overalljails = true;
    };
    ignoreIP = [
      "127.0.0.0/8"
    ];
  };

  system.autoUpgrade = {
    enable = true;
    operation = "boot";
    flake = "github:sspeaks/nixos-config#vid-stream";
    dates = "04:30";
    randomizedDelaySec = "15min";
    allowReboot = true;
  };

  systemd.tmpfiles.rules = [
    "z /srv/videos 0750 sspeaks users -"
  ];

  networking.firewall.allowedTCPPorts = [
    8080
    8081
  ];

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
}
