{ config, lib, ... }:
{
  sops.secrets = {
    wifi-password = {
      format = "yaml";
      sopsFile = ../secrets.yaml;
    };
  };
  boot.extraModprobeConfig = ''
    options cfg80211 ieee80211_regdom="US"
    options mt76_usb disable_usb_sg=1
    options iwlwifi lar_disable=1
  '';
  boot.kernelPatches = [{
    name = "cfg80211-config";
    patch = null;
    extraStructuredConfig = with lib.kernel; {
      EXPERT = yes;
      CFG80211_REQUIRE_SIGNED_REGDB = no;
      CFG80211_CERTIFICATION_ONUS = yes;
      CFG80211_REG_RELAX_NO_IR = yes;
    };
  }];
  services.hostapd = {
    enable = true;
    radios = {
      wlp1s0 = {
        band = "5g";
        countryCode = "US";
        channel = 44;

        wifi4.enable = true;
        # Values found in https://w1.fi/cgit/hostap/plain/hostapd/hostapd.conf
        wifi4.capabilities = [
          "HT40-"
          "HT40+"
          # "LDPC"
          # "SMPS disabled"
          # "SHORT-GI-20"
          # "SHORT-GI-40"
          # "GF"
          # "TX-STBC"
          # "RX-STBC1"
        ];
        # wifi5.capabilities = [
        #   "MAX-MPDU-3895"
        #   "RXLDPC"
        #   "SHORT-GI-80"
        # ];

        networks = {
          wlp1s0  = {
            ssid = "youdontknowme5";
            bssid = "c8:8a:9a:6c:ef:80";
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
