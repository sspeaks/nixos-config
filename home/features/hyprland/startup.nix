{ asahiPaths, pkgs, ... }:

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

  systemd.user.services.swaybg-refresh = {
    Unit = {
      Description = "Refresh Hyprland wallpaper";
      After = [ "swaybg.service" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl --user restart swaybg.service";
    };
  };

  systemd.user.paths.swaybg-wallpaper = {
    Unit = {
      Description = "Watch Bing wallpaper changes";
      PartOf = [ "graphical-session.target" ];
    };

    Path = {
      PathChanged = [ asahiPaths.wallpaper ];
      Unit = "swaybg-refresh.service";
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
