{ pkgs, config, ... }:
let
  sopsFileLocation = {
    format = "yaml";
    sopsFile = ../../secrets/nixpi5.yaml;
  };

  cameras = {
    away_driveway = "192.168.2.73";
    backyard_hottub = "192.168.2.193";
    bottom_floor = "192.168.2.46";
    covered_parking = "192.168.2.171";
    empty_lot = "192.168.2.104";
    extended_driveway = "192.168.2.29";
    front_of_garage = "192.168.2.197";
    front_porch = "192.168.2.91";
    garage = "192.168.2.24";
    neighbor_facing_driveway = "192.168.2.156";
  };

  # HA entity ID -> go2rtc stream name mapping
  entityAliases = {
    "camera.192_168_2_73" = "away_driveway";
    "camera.192_168_2_193" = "backyard_hottub";
    "camera.192_168_2_46" = "bottom_floor";
    "camera.192_168_2_171" = "covered_parking";
    "camera.192_168_2_104" = "empty_lot";
    "camera.192_168_2_29" = "extended_driveway";
    "camera.192_168_2_197" = "front_of_garage";
    "camera.192_168_2_91" = "front_porch";
    "camera.192_168_2_24" = "garage";
    "camera.192_168_2_156" = "neighbor_facing_driveway";
  };

  cameraList = builtins.attrNames cameras;
  aliasList = builtins.attrNames entityAliases;

  # Named streams with direct RTSP
  streamsEntries = builtins.concatStringsSep "\n" (map
    (name: "  ${name}: \"rtsp://CAMERA_USER:CAMERA_PASS@${cameras.${name}}:554/media/video1\"")
    cameraList);

  # HA entity ID aliases pointing to the named stream's RTSP proxy
  aliasEntries = builtins.concatStringsSep "\n" (map
    (entityId: "  ${entityId}: \"rtsp://127.0.0.1:8554/${entityAliases.${entityId}}\"")
    aliasList);

  configTemplate = pkgs.writeText "go2rtc.yaml.tmpl" ''
    streams:
    ${streamsEntries}
    ${aliasEntries}
    api:
      listen: ":1984"
      readonly: true
    rtsp:
      listen: ":8554"
    webrtc:
      listen: ":8555"
  '';

  preStartScript = pkgs.writeShellScript "go2rtc-prestart" ''
    CAMERA_USER=$(cat ${config.sops.secrets.GO2RTC_CAMERA_USER.path})
    CAMERA_PASS=$(cat ${config.sops.secrets.GO2RTC_CAMERA_PASS.path})
    ${pkgs.gnused}/bin/sed \
      -e "s|CAMERA_USER|$CAMERA_USER|g" \
      -e "s|CAMERA_PASS|$CAMERA_PASS|g" \
      ${configTemplate} > /run/go2rtc/go2rtc.yaml
  '';
in
{
  sops.secrets = {
    GO2RTC_CAMERA_USER = sopsFileLocation // { owner = "go2rtc"; };
    GO2RTC_CAMERA_PASS = sopsFileLocation // { owner = "go2rtc"; };
  };

  users.users.go2rtc = {
    isSystemUser = true;
    group = "go2rtc";
  };
  users.groups.go2rtc = { };

  systemd.services.go2rtc = {
    description = "go2rtc camera streaming proxy";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.ffmpeg ];
    serviceConfig = {
      ExecStartPre = "${preStartScript}";
      ExecStart = "${pkgs.go2rtc}/bin/go2rtc -config /run/go2rtc/go2rtc.yaml";
      Restart = "on-failure";
      RestartSec = 5;
      RuntimeDirectory = "go2rtc";
      User = "go2rtc";
      Group = "go2rtc";
    };
  };

  networking.firewall.allowedTCPPorts = [ 1984 8554 8555 ];
  networking.firewall.allowedUDPPorts = [ 8555 ];
}
