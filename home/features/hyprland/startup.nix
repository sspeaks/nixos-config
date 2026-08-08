{ asahiPaths, pkgs, ... }:

# Plate XIV startup slice — Hyprland only.
# Wallpaper is sourced from the immutable store path provided by Tank;
# the mutable-path watcher units (swaybg-refresh, swaybg-wallpaper path)
# are removed. swaybg runs as a plain systemd service against a fixed path.
# Quickshell is NOT launched here — it belongs in niri's spawn-at-startup
# once the niri session is activated.
let
  swaybgCommand = "${pkgs.swaybg}/bin/swaybg -i ${asahiPaths.wallpaper} -m fill";
in
{
  wayland.windowManager.hyprland.settings.exec-once = [
    "waybar"
    "blueman-applet"
    "wl-paste --type text --watch cliphist store"
    "wl-paste --type image --watch cliphist store"
    "lxqt-policykit-agent"
    "gnome-keyring-daemon --start --components=secrets"
  ];

  systemd.user.services.swaybg = {
    Unit = {
      Description = "Hyprland wallpaper";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = swaybgCommand;
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
