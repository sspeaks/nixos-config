{ ... }:

let
  plate = import ../theme/plate.nix;
  dimmingSentinel = "$XDG_RUNTIME_DIR/hypridle-dimming";
in
{
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        disable_loading_bar = true;
        grace = 5;
        hide_cursor = true;
        no_fade_in = false;
      };

      background = [
        {
          path = "screenshot";
          blur_passes = 3;
          blur_size = 8;
        }
      ];

      label = [
        {
          monitor = "";
          text = "$TIME";
          color = plate.hyprRgba plate.fg.primary "FF";
          font_size = 72;
          font_family = plate.type.mono;
          position = "0, 90";
          halign = "center";
          valign = "center";
        }
        {
          monitor = "";
          text = "Hi, $USER";
          color = plate.hyprRgba plate.fg.secondary "E6";
          font_size = 18;
          font_family = plate.type.mono;
          position = "0, 20";
          halign = "center";
          valign = "center";
        }
        {
          monitor = "";
          text = ''cmd[update:60000] date +"%A, %B %d"'';
          color = plate.hyprRgb plate.fg.secondary;
          font_size = 16;
          font_family = plate.type.mono;
          position = "0, 175";
          halign = "center";
          valign = "center";
        }
      ];

      input-field = [
        {
          size = "200, 50";
          position = "0, -80";
          monitor = "";
          dots_center = true;
          fade_on_empty = false;
          font_color = plate.hyprRgb plate.fg.primary;
          inner_color = plate.hyprRgb plate.bg.inset;
          outer_color = plate.hyprRgb plate.line.edge;
          check_color = plate.hyprRgb plate.state.warn;
          fail_color = plate.hyprRgb plate.state.fail;
          outline_thickness = 3;
          placeholder_text = "Password…";
          shadow_passes = 2;
        }
      ];
    };
  };

  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        # packages/plate-wrappers selects niri or Hyprland for DPMS actions.
        after_sleep_cmd = "plate-dpms-on";
      };

      listener = [
        {
          timeout = 300;
          on-timeout = "touch ${dimmingSentinel} && brightnessctl -d apple-panel-bl -s set 30%";
          on-resume = "rm -f ${dimmingSentinel} && brightnessctl -d apple-panel-bl -r";
        }
        {
          timeout = 600;
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 900;
          on-timeout = "plate-dpms-off";
          on-resume = "plate-dpms-on";
        }
        {
          timeout = 1800;
          on-timeout = "grep -q 1 /sys/class/power_supply/*/online 2>/dev/null || systemctl suspend";
        }
      ];
    };
  };
}
