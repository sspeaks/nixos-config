{ config, pkgs, lib, ... }:

let
  palette = import ../../home/features/theme/palette.nix;
  mocha = palette.mocha;
in
{
  programs.waybar = {
    enable = true;
    systemd.enable = false; # Started by Hyprland exec-once
    style = ''
      * {
        font-family: ${palette.fonts.monoCss};
        font-size: 13px;
        min-height: 0;
      }

      /* Transparent bar strip: each module floats as its own frosted island. */
      window#waybar {
        background: transparent;
      }

      tooltip {
        background: ${palette.surfaces.tooltip};
        border: 1px solid ${palette.surfaces.border};
        border-radius: ${palette.radius.md};
      }

      tooltip label {
        color: ${mocha.text};
      }

      /* Shared floating-island styling for every module. */
      #workspaces,
      #window,
      #clock,
      #battery,
      #cpu,
      #memory,
      #network,
      #custom-volume,
      #backlight,
      #bluetooth,
      #temperature,
      #custom-wireguard,
      #power-profiles-daemon,
      #tray,
      #custom-power {
        background: ${palette.surfaces.island};
        border: 1px solid ${palette.surfaces.border};
        border-radius: ${palette.radius.md};
        box-shadow: 0 2px 6px ${palette.surfaces.shadow};
        margin: 5px 3px;
        padding: 4px 12px;
        color: ${mocha.text};
        transition: all 0.2s ease;
      }

      /* Interactive info pills brighten their border on hover. */
      #clock:hover,
      #battery:hover,
      #cpu:hover,
      #memory:hover,
      #network:hover,
      #custom-volume:hover,
      #backlight:hover,
      #bluetooth:hover,
      #temperature:hover {
        border-color: ${palette.accent};
      }

      #workspaces {
        padding: 2px 6px;
      }

      #workspaces button {
        padding: 2px 9px;
        margin: 2px;
        min-width: 20px;
        color: ${mocha.overlay1};
        border-radius: ${palette.radius.sm};
        background: transparent;
        transition: all 0.2s ease;
      }

      #workspaces button:hover {
        background: ${palette.surfaces.accentSoft};
        color: ${palette.accent};
      }

      #workspaces button.active {
        background: ${palette.accent};
        color: ${mocha.crust};
        box-shadow: 0 0 8px ${palette.surfaces.accentActive};
      }

      #workspaces button.urgent {
        background: ${palette.surfaces.urgentSoft};
        color: ${mocha.red};
      }

      #window {
        color: ${mocha.subtext0};
        font-style: italic;
        padding: 4px 15px;
      }

      /* Hide the window pill entirely when no window is focused. */
      #window.empty {
        background: transparent;
        border-color: transparent;
        box-shadow: none;
      }

      #clock {
        color: ${mocha.sky};
        font-weight: bold;
      }

      #battery {
        color: ${mocha.green};
      }

      #battery.charging {
        color: ${mocha.green};
      }

      #battery.warning:not(.charging) {
        color: ${mocha.peach};
      }

      #battery.critical:not(.charging) {
        color: ${mocha.red};
        animation: blink 0.5s linear infinite alternate;
      }

      @keyframes blink {
        to {
          background: ${palette.surfaces.urgentSoft};
        }
      }

      #cpu {
        color: ${mocha.blue};
      }

      #memory {
        color: ${mocha.mauve};
      }

      #network {
        color: ${mocha.teal};
      }

      #network.disconnected {
        color: ${mocha.red};
      }

      #custom-volume {
        color: ${mocha.yellow};
      }

      #custom-volume.muted {
        color: ${mocha.overlay0};
      }

      #backlight {
        color: ${mocha.yellow};
      }

      #backlight-slider slider {
        min-height: 0px;
        min-width: 0px;
        opacity: 0;
        background-image: none;
        border: none;
        box-shadow: none;
      }

      #backlight-slider trough {
        min-height: 8px;
        min-width: 80px;
        border-radius: 5px;
        background-color: ${palette.surfaces.panel};
      }

      #backlight-slider highlight {
        min-height: 8px;
        border-radius: 5px;
        background-color: ${mocha.yellow};
      }

      #bluetooth {
        color: ${mocha.blue};
      }

      #bluetooth.disabled {
        color: ${mocha.overlay0};
      }

      #temperature {
        color: ${mocha.green};
      }

      #temperature.critical {
        color: ${mocha.red};
      }

      #power-profiles-daemon {
        color: ${mocha.teal};
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
        color: ${mocha.red};
      }

      #custom-power:hover {
        background: ${palette.surfaces.urgentSoft};
        border-color: ${mocha.red};
      }

      #custom-wireguard {
        color: ${mocha.green};
      }
    '';

    settings = {
      mainBar = {
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
          "backlight/slider"
          "custom/volume"
          "bluetooth"
          "custom/wireguard"
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
          format = "  {:%I:%M %p}";
          format-alt = "  {:%A, %B %d, %Y}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "year";
            mode-mon-col = 3;
            weeks-pos = "right";
            on-scroll = 1;
            format = {
              months = "<span color='${mocha.yellow}'><b>{}</b></span>";
              days = "<span color='${mocha.text}'><b>{}</b></span>";
              weeks = "<span color='${mocha.teal}'><b>W{}</b></span>";
              weekdays = "<span color='${mocha.peach}'><b>{}</b></span>";
              today = "<span color='${mocha.green}'><b><u>{}</u></b></span>";
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
          format = "󰍛  {usage}%";
          tooltip-format = "CPU: {usage}%\nLoad: {load}";
          on-click = "ghostty -e htop";
        };

        memory = {
          interval = 5;
          format = "󰘚  {}%";
          tooltip-format = "RAM: {used:0.1f}GB / {total:0.1f}GB";
          on-click = "ghostty -e htop";
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

        "custom/volume" = {
          exec = pkgs.writeShellScript "waybar-volume" ''
            emit() {
              output=$(${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
              vol=$(echo "$output" | ${pkgs.gawk}/bin/awk '{printf "%.0f", $2 * 100}')
              muted=""
              if echo "$output" | grep -q MUTED; then
                muted="muted"
              fi

              if [ -n "$muted" ]; then
                icon="󰝟"
                text="$icon  muted"
              elif [ "$vol" -le 30 ]; then
                icon="󰕿"
                text="$icon  $vol%"
              elif [ "$vol" -le 70 ]; then
                icon="󰖀"
                text="$icon  $vol%"
              else
                icon="󰕾"
                text="$icon  $vol%"
              fi

              echo "{\"text\": \"$text\", \"tooltip\": \"Volume: $vol%\", \"class\": \"$muted\"}"
            }

            emit
            ${pkgs.pulseaudio}/bin/pactl subscribe | while read -r line; do
              if echo "$line" | grep -q "change.*sink"; then
                emit
              fi
            done
          '';
          return-type = "json";
          on-click = "pavucontrol";
          on-click-right = "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
          on-scroll-up = "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
          on-scroll-down = "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
        };

        backlight = {
          format = "{icon}  {percent}%";
          format-icons = [ "󰃞" "󰃟" "󰃠" ];
          tooltip-format = "Brightness: {percent}%";
          on-click = "brightnessctl -d apple-panel-bl set 100% && echo 100 > /tmp/auto-brightness-user-pct";
          on-click-right = "brightnessctl -d apple-panel-bl set 30% && echo 30 > /tmp/auto-brightness-user-pct";
          on-scroll-up = "brightnessctl -d apple-panel-bl set 5%+ && echo $(( $(brightnessctl -d apple-panel-bl get) * 100 / $(brightnessctl -d apple-panel-bl max) )) > /tmp/auto-brightness-user-pct";
          on-scroll-down = "brightnessctl -d apple-panel-bl set 5%- && echo $(( $(brightnessctl -d apple-panel-bl get) * 100 / $(brightnessctl -d apple-panel-bl max) )) > /tmp/auto-brightness-user-pct";
        };

        "backlight/slider" = {
          min = 0;
          max = 100;
          orientation = "horizontal";
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

        "custom/wireguard" = {
          exec = pkgs.writeShellScript "waybar-wireguard" ''
            if ip link show wg0 &>/dev/null; then
              fwmark=$(${pkgs.wireguard-tools}/bin/wg show wg0 fwmark 2>/dev/null)
              if [ -n "$fwmark" ] && ${pkgs.iptables}/bin/iptables -C OUTPUT ! -o wg0 -m mark ! --mark "$fwmark" -m addrtype ! --dst-type LOCAL -j REJECT &>/dev/null; then
                echo '{"text": "󰌾", "tooltip": "WireGuard active, kill switch on", "class": "connected"}'
              else
                echo '{"text": "󰌾", "tooltip": "WireGuard active", "class": "connected"}'
              fi
            else
              echo '{"text": "", "tooltip": "", "class": ""}'
            fi
          '';
          return-type = "json";
          interval = 5;
          tooltip = true;
        };

        "custom/power" = {
          format = "󰐥";
          tooltip = false;
          on-click = "wlogout";
        };
      };
    };
  };
}
