{ config, pkgs, lib, asahiPaths, ... }:

let
  wallpaper = lib.escapeShellArg asahiPaths.wallpaper;
  wallpaperTmp = lib.escapeShellArg "${asahiPaths.wallpaper}.tmp";
  bingWallpaperScript = pkgs.writeShellScript "bing-wallpaper" ''
    set -euo pipefail

    wallpaper_dir="$(${pkgs.coreutils}/bin/dirname ${wallpaper})"
    wallpaper_tmp=${wallpaperTmp}
    ${pkgs.coreutils}/bin/mkdir -p "$wallpaper_dir"

    metadata="$(${pkgs.curl}/bin/curl --fail --silent --show-error --location --retry 3 --retry-delay 2 'https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=en-US')"
    url_path="$(printf '%s' "$metadata" | ${pkgs.jq}/bin/jq -r '.images[0].url')"
    image_url="https://www.bing.com$url_path"

    ${pkgs.curl}/bin/curl --fail --silent --show-error --location --retry 3 --retry-delay 2 "$image_url" --output "$wallpaper_tmp"
    ${pkgs.coreutils}/bin/mv "$wallpaper_tmp" ${wallpaper}
    ${pkgs.coreutils}/bin/chmod 644 ${wallpaper}
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
