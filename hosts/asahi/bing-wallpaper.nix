{ config, pkgs, lib, ... }:

let
  bingWallpaperScript = pkgs.writeShellScript "bing-wallpaper" ''
    set -euo pipefail

    WALLPAPER="/var/lib/bing-wallpaper/wallpaper.jpg"
    mkdir -p /var/lib/bing-wallpaper

    # Fetch Bing wallpaper of the day metadata
    JSON=$(${pkgs.curl}/bin/curl -sf "https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=en-US")
    if [ -z "$JSON" ]; then
      echo "Failed to fetch Bing metadata"
      exit 1
    fi

    URL_PATH=$(echo "$JSON" | ${pkgs.jq}/bin/jq -r '.images[0].url')
    FULL_URL="https://www.bing.com''${URL_PATH}"

    # Download the image
    ${pkgs.curl}/bin/curl -sf -o "$WALLPAPER" "$FULL_URL"
    chmod 644 "$WALLPAPER"
    echo "Downloaded: $FULL_URL"
  '';
in
{
  systemd.services.bing-wallpaper = {
    description = "Fetch Bing Wallpaper of the Day";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${bingWallpaperScript}";
    };
  };

  systemd.timers.bing-wallpaper = {
    description = "Fetch Bing Wallpaper of the Day";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      OnBootSec = "30s";
      Persistent = true;
    };
  };
}
