{ ... }:
{
  networking.wireless = {
    enable = true;
    interfaces = [ "wlan0" ];
    networks = {
      "SethPhone" = {
        pskRaw = "074a0c1d175390072ecdbe9ad918d4459d1e376b2c9da370057938cb203b734c";
      };
      "hide your kids hide your wifi" = {
        pskRaw = "";
      };
      "Starbucks WiFi" = {
        auth = ''
          key_mgmt=NONE
        '';
      };
    };
  };

}

