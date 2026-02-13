{ config, pkgs, lib, ... }:

{
  programs.waybar = {
    enable = true;
    systemd.enable = false;  # Started by Hyprland exec-once
    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", "JetBrains Mono Nerd Font", "JetBrains Mono", "Symbols Nerd Font", "Font Awesome 6 Free", monospace;
        font-size: 13px;
        min-height: 0;
      }

      window#waybar {
        background: rgba(21, 22, 30, 0.8);
        border-bottom: none;
      }

      tooltip {
        background: rgba(21, 22, 30, 0.9);
        border: 1px solid rgba(100, 114, 125, 0.5);
        border-radius: 8px;
      }

      tooltip label {
        color: #cdd6f4;
      }

      #workspaces {
        margin: 5px;
        padding: 0 5px;
        background: rgba(30, 30, 46, 0.6);
        border-radius: 10px;
      }

      #workspaces button {
        padding: 2px 8px;
        margin: 2px;
        color: #6c7086;
        border-radius: 6px;
        background: transparent;
        transition: all 0.2s ease;
      }

      #workspaces button:hover {
        background: rgba(137, 180, 250, 0.2);
        color: #89b4fa;
      }

      #workspaces button.active {
        background: rgba(137, 180, 250, 0.3);
        color: #89b4fa;
      }

      #workspaces button.urgent {
        background: rgba(243, 139, 168, 0.3);
        color: #f38ba8;
      }

      #window {
        color: #cdd6f4;
        padding: 0 15px;
      }

      #clock,
      #battery,
      #cpu,
      #memory,
      #network,
      #pulseaudio,
      #backlight,
      #bluetooth,
      #temperature,
      #tray {
        padding: 4px 12px;
        margin: 5px 3px;
        background: rgba(30, 30, 46, 0.6);
        border-radius: 10px;
        color: #cdd6f4;
      }

      #clock {
        color: #89dceb;
      }

      #battery {
        color: #a6e3a1;
      }

      #battery.charging {
        color: #a6e3a1;
      }

      #battery.warning:not(.charging) {
        color: #fab387;
      }

      #battery.critical:not(.charging) {
        color: #f38ba8;
        animation: blink 0.5s linear infinite alternate;
      }

      @keyframes blink {
        to {
          background: rgba(243, 139, 168, 0.3);
        }
      }

      #cpu {
        color: #89b4fa;
      }

      #memory {
        color: #cba6f7;
      }

      #network {
        color: #94e2d5;
      }

      #network.disconnected {
        color: #f38ba8;
      }

      #pulseaudio {
        color: #f9e2af;
      }

      #pulseaudio.muted {
        color: #6c7086;
      }

      #backlight {
        color: #f9e2af;
      }

      #bluetooth {
        color: #89b4fa;
      }

      #bluetooth.disabled {
        color: #6c7086;
      }

      #temperature {
        color: #a6e3a1;
      }

      #temperature.critical {
        color: #f38ba8;
      }

      #power-profiles-daemon {
        padding: 4px 12px;
        margin: 5px 3px;
        background: rgba(30, 30, 46, 0.6);
        border-radius: 10px;
        color: #94e2d5;
      }

      #tray {
        padding: 4px 8px;
      }

      #tray > .passive {
        -gtk-icon-effect: dim;
      }

      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
      }

      #custom-power {
        color: #f38ba8;
        padding: 4px 12px;
        margin: 5px 3px;
        background: rgba(30, 30, 46, 0.6);
        border-radius: 10px;
      }

      #custom-power:hover {
        background: rgba(243, 139, 168, 0.3);
      }
    '';

    settings = [{
      height = 34;
      layer = "top";
      position = "bottom";
      margin-bottom = 5;
      margin-left = 10;
      margin-right = 10;
      spacing = 0;

      modules-left = [
        "hyprland/workspaces"
        "hyprland/window"
      ];

      modules-center = [
        "clock"
      ];

      modules-right = [
        "tray"
        "backlight"
        "pulseaudio"
        "bluetooth"
        "network"
        "cpu"
        "memory"
        "power-profiles-daemon"
        "battery"
        "custom/power"
      ];

      "hyprland/workspaces" = {
        format = "{icon}";
        format-icons = {
          "1" = "1";
          "2" = "2";
          "3" = "3";
          "4" = "4";
          "5" = "5";
          "6" = "6";
          "7" = "7";
          "8" = "8";
          "9" = "9";
          "10" = "0";
          urgent = "";
          default = "";
        };
        on-click = "activate";
        sort-by-number = true;
      };

      "hyprland/window" = {
        max-length = 50;
        separate-outputs = true;
      };

      clock = {
        format = "  {:%H:%M}";
        format-alt = "  {:%A, %B %d, %Y}";
        tooltip-format = "<tt><small>{calendar}</small></tt>";
        calendar = {
          mode = "year";
          mode-mon-col = 3;
          weeks-pos = "right";
          on-scroll = 1;
          format = {
            months = "<span color='#f9e2af'><b>{}</b></span>";
            days = "<span color='#cdd6f4'><b>{}</b></span>";
            weeks = "<span color='#94e2d5'><b>W{}</b></span>";
            weekdays = "<span color='#fab387'><b>{}</b></span>";
            today = "<span color='#a6e3a1'><b><u>{}</u></b></span>";
          };
        };
        actions = {
          on-click-right = "mode";
          on-scroll-up = "shift_up";
          on-scroll-down = "shift_down";
        };
      };

      battery = {
        interval = 10;
        states = {
          warning = 30;
          critical = 15;
        };
        format = "{icon}  {capacity}%";
        format-charging = "󰂄  {capacity}%";
        format-plugged = "󰚥  {capacity}%";
        format-icons = [ "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
        tooltip-format = "{timeTo} | {power:.1f}W";
      };

      "power-profiles-daemon" = {
        format = "{icon}";
        tooltip-format = "Power profile: {profile}\nDriver: {driver}";
        tooltip = true;
        format-icons = {
          default = "󰗑";
          performance = "󰓅";
          balanced = "󰗑";
          power-saver = "󰌪";
        };
      };

      cpu = {
        interval = 5;
        format = "  {usage}%";
        tooltip-format = "CPU: {usage}%\nLoad: {load}";
        on-click = "alacritty -e htop";
      };

      memory = {
        interval = 5;
        format = "  {}%";
        tooltip-format = "RAM: {used:0.1f}GB / {total:0.1f}GB";
        on-click = "alacritty -e htop";
      };

      network = {
        interval = 5;
        format-wifi = "󰤨  {signalStrength}%";
        format-ethernet = "󰈀  {ipaddr}";
        format-linked = "󰈀  No IP";
        format-disconnected = "󰤭  Offline";
        tooltip-format-wifi = "{essid}\n{ipaddr}/{cidr}\n↓ {bandwidthDownBytes} ↑ {bandwidthUpBytes}";
        tooltip-format-ethernet = "{ifname}\n{ipaddr}/{cidr}\n↓ {bandwidthDownBytes} ↑ {bandwidthUpBytes}";
        on-click = "iwgtk";
      };

      pulseaudio = {
        format = "{icon}  {volume}%";
        format-bluetooth = "󰂯  {volume}%";
        format-bluetooth-muted = "󰂲  muted";
        format-muted = "󰝟  muted";
        format-icons = {
          headphone = "󰋋";
          hands-free = "󰋎";
          headset = "󰋎";
          phone = "";
          portable = "";
          car = "󰄋";
          default = [ "󰕿" "󰖀" "󰕾" ];
        };
        tooltip-format = "{desc}\n{volume}%";
        on-click = "pavucontrol";
        on-click-right = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        scroll-step = 5;
      };

      backlight = {
        format = "{icon}  {percent}%";
        format-icons = [ "󰃞" "󰃟" "󰃠" ];
        tooltip-format = "Brightness: {percent}%";
        on-click = "brightnessctl set 100%";
        on-click-right = "brightnessctl set 30%";
        on-scroll-up = "brightnessctl set 5%+";
        on-scroll-down = "brightnessctl set 5%-";
      };

      bluetooth = {
        format = "󰂯";
        format-connected = "󰂱  {num_connections}";
        format-disabled = "󰂲";
        tooltip-format = "{controller_alias}\n{num_connections} connected";
        tooltip-format-connected = "{controller_alias}\n{num_connections} connected\n\n{device_enumerate}";
        tooltip-format-enumerate-connected = "{device_alias}";
        on-click = "blueman-manager";
      };

      tray = {
        icon-size = 16;
        spacing = 8;
      };

      "custom/power" = {
        format = "󰐥";
        tooltip = false;
        on-click = "wlogout";
      };
    }];
  };
}
