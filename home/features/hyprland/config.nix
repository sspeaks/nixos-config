{ ... }:

# Plate XIV compositor slice — flat, restrained, token-driven.
# Rounding/blur/shadow/dim are all off. Square, opaque, 1 px border.
let
  plate = import ../theme/plate.nix;
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
        gaps_in = 4;
        gaps_out = 8;
        border_size = 1;
        "col.active_border" = plate.hyprRgba plate.accent.vermilion "ff";
        "col.inactive_border" = plate.hyprRgba plate.line.rule "ff";
        layout = "dwindle";
        allow_tearing = false;
      };

      decoration = {
        rounding = 0;
        active_opacity = 1.0;
        inactive_opacity = 1.0;
        dim_inactive = false;
        blur.enabled = false;
        shadow.enabled = false;
      };

      animations = {
        enabled = true;
        bezier = [
          "easeCrisp, 0.16, 1, 0.3, 1"
        ];
        animation = [
          "windows,    1, 3, linear, slide"
          "workspaces, 1, 4, easeCrisp, slide"
          "fade,       1, 4, default"
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
    };
  };
}
