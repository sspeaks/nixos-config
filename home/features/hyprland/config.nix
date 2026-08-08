{ ... }:

let
  palette = import ../theme/palette.nix;
  mocha = palette.mocha;
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "hyprlang";
    systemd.enable = true;
    xwayland.enable = true;
    settings = {
      monitor = [
        ",preferred,auto,1.5"
      ];

      env = [
        "XCURSOR_SIZE,36"
        "HYPRCURSOR_SIZE,36"
      ];

      xwayland.force_zero_scaling = true;

      input = {
        kb_layout = "us";
        follow_mouse = 1;
        sensitivity = 0;
        touchpad.natural_scroll = true;
      };

      general = {
        gaps_in = 6;
        gaps_out = 14;
        border_size = 2;
        "col.active_border" = "${palette.rgba palette.accent "ee"} ${palette.rgba palette.accentAlt "ee"} 45deg";
        "col.inactive_border" = palette.rgba mocha.overlay0 "aa";
        layout = "dwindle";
        allow_tearing = false;
      };

      decoration = {
        rounding = 12;
        active_opacity = 1.0;
        inactive_opacity = 0.97;
        dim_inactive = true;
        dim_strength = 0.08;
        blur = {
          enabled = true;
          size = 5;
          passes = 2;
          new_optimizations = true;
          ignore_opacity = true;
          vibrancy = 0.1696;
        };
        shadow = {
          enabled = true;
          range = 12;
          render_power = 3;
          # Focused windows get a soft accent halo; others a plain dark shadow.
          color = palette.rgba palette.accent "33";
          color_inactive = palette.rgba mocha.crust "cc";
        };
      };

      animations = {
        enabled = true;
        bezier = [
          "myBezier, 0.05, 0.9, 0.1, 1.05"
          "easeOutQuint, 0.23, 1, 0.32, 1"
          "easeInOutCubic, 0.65, 0, 0.35, 1"
        ];
        animation = [
          "windows, 1, 6, myBezier, slide"
          "windowsOut, 1, 6, easeOutQuint, popin 80%"
          "windowsMove, 1, 5, myBezier, slide"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, easeOutQuint, slide"
          "specialWorkspace, 1, 6, easeOutQuint, slidevert"
        ];
      };

      dwindle = {
        preserve_split = true;
      };

      master.new_status = "master";

      misc = {
        force_default_wallpaper = 0;
        disable_hyprland_logo = true;
      };

      layerrule = [
        "blur on, ignore_alpha 0, match:namespace waybar"
        "blur on, ignore_alpha 0, match:namespace notifications"
      ];
    };
  };
}
