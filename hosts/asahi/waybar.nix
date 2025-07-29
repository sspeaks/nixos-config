{ config, pkgs, lib, ... }:

{
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    style = ''
      ${builtins.readFile "${pkgs.waybar}/etc/xdg/waybar/style.css"}

      window#waybar {
        background: transparent;
        border-bottom: none;
      }
      #backlight-slider slider {
        min-height: 10px;
        min-width: 10px;
        color: white;
      }
      #backlight-slider trough {
          min-height: 10px;
          min-width: 80px;
          border-radius: 5px;
          background-color: black;
      }
      #backlight-slider highlight {
          min-width: 10px;
          border-radius: 5px;
          background-color: red;
      }
    '';
    settings = [{
      height = 30;
      layer = "top";
      position = "bottom";
      tray = { spacing = 10; };
      modules-center = [ "hyprland/window" ];
      modules-left = [ "hyprland/workspaces" "backlight/slider" ];
      modules-right = [
        "pulseaudio"
        "network"
        "cpu"
        "memory"
        "battery"
      ] ++ [
        "clock"
        "tray"
      ];
      "backlight/slider" = {
        "min" = 0;
        "max" = 100;
        "orientation" = "horizontal";
      };
      battery = {
        format = "{capacity}% {icon}";
        format-alt = "{time} {icon}";
        format-charging = "{capacity}% ";
        format-icons = [ "" "" "" "" "" ];
        format-plugged = "{capacity}% ";
        states = {
          critical = 15;
          warning = 30;
        };
      };
      clock = {
        format-alt = "{:%Y-%m-%d}";
        tooltip-format = "{:%Y-%m-%d | %H:%M}";
      };
      cpu = {
        format = "{usage}% ";
        tooltip = false;
      };
      memory = { format = "{}% "; };
      network = {
        interval = 1;
        format-alt = "{ifname}: {ipaddr}/{cidr}";
        format-disconnected = "Disconnected ⚠";
        format-ethernet = "{ifname}: {ipaddr}/{cidr}   up: {bandwidthUpBits} down: {bandwidthDownBits}";
        format-linked = "{ifname} (No IP) ";
        format-wifi = "{essid} ({signalStrength}%) ";
      };
      pulseaudio = {
        format = "{volume}% {icon} {format_source}";
        format-bluetooth = "{volume}% {icon} {format_source}";
        format-bluetooth-muted = " {icon} {format_source}";
        format-icons = {
          car = "";
          default = [ "" "" "" ];
          handsfree = "";
          headphones = "";
          headset = "";
          phone = "";
          portable = "";
        };
        format-muted = " {format_source}";
        format-source = "{volume}% ";
        format-source-muted = "";
        on-click = "pavucontrol";
      };
      temperature = {
        critical-threshold = 80;
        format = "{temperatureC}°C {icon}";
        format-icons = [ "" "" "" ];
      };
    }];
  };
}
