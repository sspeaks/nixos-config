{ config, ... }:
{
  sops.secrets = {
    wifi-password = {
      format = "yaml";
      sopsFile = ../secrets.yaml;
    };
  };
  services.hostapd = {
    enable = true;
    radios = {
      wlp1s0u2 = {
        band = "5g";
        countryCode = "US";
        channel = 40;

        wifi4.enable = true;
        wifi4.capabilities = [ "LDPC" "HT40+" "SMPS disabled" "SHORT-GI-20" "SHORT-GI-40" "GF" "TX-STBC" "RX-STBC1" ];


        networks = {
          wlp1s0u2 = {
            ssid = "youdontknowme";
            bssid = "80:cc:9c:82:9f:27";
            authentication = {
              mode = "wpa2-sha256";
              wpaPasswordFile = config.sops.secrets.wifi-password.path;
            };
            settings = {
              bridge = "br-lan";
            };
          };
        };

      };
    };
  };
}
