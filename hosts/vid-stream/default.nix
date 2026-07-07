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
    inputs.determinate.nixosModules.default
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
  };

  users.users.vid-streamer.extraGroups = [ "users" ];
  systemd.services.vid-streamer.serviceConfig.SupplementaryGroups = [ "users" ];

  systemd.tmpfiles.rules = [
    "d /srv/videos 0750 sspeaks users -"
    "d /var/lib/vid-streamer/hls 0750 vid-streamer vid-streamer -"
  ];

  services.vidStreamer = {
    enable = true;
    package = inputs.large-video-streamer.packages.${pkgs.stdenv.hostPlatform.system}.default;
    videoDir = "/srv/videos";
    listenAddr = "0.0.0.0:8080";
    openFirewall = true;
    loginUserFile = config.sops.secrets.vid-streamer-login-user.path;
    loginPassFile = config.sops.secrets.vid-streamer-login-pass.path;
  };
}
