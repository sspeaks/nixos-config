{ asahiPaths, ... }:

{
  wayland.windowManager.hyprland.settings.exec-once = [
    "swaybg -i ${asahiPaths.wallpaper} -m fill"
    "waybar"
    "wl-paste --type text --watch cliphist store"
    "wl-paste --type image --watch cliphist store"
    "lxqt-policykit-agent"
    "gnome-keyring-daemon --start --components=secrets"
  ];
}
