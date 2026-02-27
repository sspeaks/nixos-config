{ config, lib, pkgs, ... }:
let
  # Fallback script: checks if the driver supports ACS survey, and if not,
  # patches the hostapd config to use a fixed channel instead of ACS.
  acsFallbackScript = pkgs.writeShellScript "acs-fallback" ''
    HOSTAPD_CONFIG="$1"
    IFACE="wlp1s0u2"
    FALLBACK_CHANNEL=44

    # Get the phy for this interface
    PHY=$(${pkgs.iw}/bin/iw dev "$IFACE" info 2>/dev/null | grep wiphy | awk '{print "phy"$2}')
    if [ -z "$PHY" ]; then
      echo "acs-fallback: could not determine phy for $IFACE, falling back to channel $FALLBACK_CHANNEL"
      ${pkgs.gnused}/bin/sed -i "s/^channel=0$/channel=$FALLBACK_CHANNEL/" "$HOSTAPD_CONFIG"
      exit 0
    fi

    # Test if the driver supports survey dump (required for ACS)
    if ! ${pkgs.iw}/bin/iw phy "$PHY" info 2>/dev/null | grep -q "survey"; then
      echo "acs-fallback: $PHY does not advertise survey support, falling back to channel $FALLBACK_CHANNEL"
      ${pkgs.gnused}/bin/sed -i "s/^channel=0$/channel=$FALLBACK_CHANNEL/" "$HOSTAPD_CONFIG"
    else
      echo "acs-fallback: $PHY supports survey, using ACS (channel=0)"
    fi
  '';
in
{
  sops.secrets = {
    wifi-password = {
      format = "yaml";
      sopsFile = ../../../secrets/nixpi.yaml;
    };
  };
  boot.extraModprobeConfig = ''
    options cfg80211 ieee80211_regdom="US"
    options mt76_usb disable_usb_sg=1
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
      wlp1s0u2 = {
        band = "5g";
        countryCode = "US";
        channel = 0; # ACS — automatically selects the best channel

        settings = {
          acs_exclude_dfs = true;
          chanlist = "36 40 44 48 149 153 157 161 165";
        };

        dynamicConfigScripts = {
          "10-acs-fallback" = acsFallbackScript;
        };

        wifi4.enable = true;
        # Values found in https://w1.fi/cgit/hostap/plain/hostapd/hostapd.conf
        # Note: HT40- removed — incompatible with ACS, and hostapd auto-selects
        # the correct HT40+/HT40- when using ACS.
        wifi4.capabilities = [
          "LDPC"
          "HT40+"
          "SMPS disabled"
          "SHORT-GI-20"
          "SHORT-GI-40"
          "GF"
          "TX-STBC"
          "RX-STBC1"
        ];
        wifi5.capabilities = [
          "MAX-MPDU-3895"
          "RXLDPC"
          "SHORT-GI-80"
        ];

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
