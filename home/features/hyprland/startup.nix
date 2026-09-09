{ asahiPaths, pkgs, ... }:

# Wallpaper uses the host's immutable store path.
# Quickshell autostart is configured in niri/config.kdl.nix, not here.
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
