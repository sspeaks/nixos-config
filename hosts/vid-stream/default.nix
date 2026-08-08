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
    ./ai-coaching.nix
  ];

  users.users.sspeaks.hashedPassword = lib.mkForce null;

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
