{ ... }:
{
  networking.wireless = {
    enable = true;
    interfaces = [ "wlan0" ];
    networks = {
      "SethPhone" = {
        pskRaw = "";
      };
      "hide your kids hide your wifi" = {
        pskRaw = "d67fd930108289665f064b2621f8b19248e5cad01e620148f5830818058de08a";
      };
      "Starbucks WiFi" = {
        auth = ''
          key_mgmt=NONE
        '';
      };
    };
  };

}

