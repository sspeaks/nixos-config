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
    GARAGE_NTFY_TOKEN = sopsFileLocation // {
      owner = "garage-monitor";
    };
    GARAGE_NFTY_USER_PASSWORD = sopsFileLocation;
  };

  services.garage-monitor = {
    enable = true;
    rtspUrl = "rtsp://192.168.2.24:554/media/video1";
    rtspUsername = "admin";
    rtspPasswordFile = config.sops.secrets.GARAGE_RTSP_PASSWORD.path;
    ntfyBaseUrl = "https://ntfy.sspeaks.net";
    ntfyTopic = "garage";
    ntfyTokenFile = config.sops.secrets.GARAGE_NTFY_TOKEN.path;
    ntfyUserPasswordFile = config.sops.secrets.GARAGE_NFTY_USER_PASSWORD.path;
    openFirewall = true;
    pollIntervalSeconds = 60;
    imageRetentionDays = 2;
  };
}
