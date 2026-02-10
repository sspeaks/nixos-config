{ config, ... }:
let
  sopsFileLocation = {
    format = "yaml";
    sopsFile = ../../secrets/nixpi5.yaml;
  };
in
{
  sops.secrets = {
    GARAGE_RTSP_PASSWORD = sopsFileLocation // {
      owner = "garage-monitor";
    };
  };

  services.garage-monitor = {
    enable = true;
    rtspUrl = "rtsp://192.168.2.24:554/media/video1";
    rtspUsername = "admin";
    rtspPasswordFile = config.sops.secrets.GARAGE_RTSP_PASSWORD.path;
  };
}
