{ ... }:

let
  palette = import ../theme/palette.nix;
  mocha = palette.mocha;
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
          color = "rgba(205, 214, 244, 1.0)";
          font_size = 72;
          font_family = palette.fonts.mono;
          position = "0, 90";
          halign = "center";
          valign = "center";
        }
        {
          monitor = "";
          text = "Hi, $USER";
          color = "rgba(166, 173, 200, 0.9)";
          font_size = 18;
          font_family = palette.fonts.mono;
          position = "0, 20";
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
          font_color = palette.rgb mocha.text;
          inner_color = palette.rgb mocha.surface0;
          outer_color = palette.rgb mocha.base;
          outline_thickness = 5;
          placeholder_text = "Password...";
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
        after_sleep_cmd = "hyprctl dispatch dpms on";
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
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        {
          timeout = 1800;
          on-timeout = "grep -q 1 /sys/class/power_supply/*/online 2>/dev/null || systemctl suspend";
        }
      ];
    };
  };
}
