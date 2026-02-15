{ config, pkgs, lib, ... }:

let
  auto-brightness = pkgs.writeShellScript "auto-brightness" ''
    ALS_PATH="/sys/bus/iio/devices/iio:device0/in_angl_raw"
    SCREEN_DEV="apple-panel-bl"
    KBD_DEV="kbd_backlight"
    USER_PCT_FILE="/tmp/auto-brightness-user-pct"

    SCREEN_MAX=$(${pkgs.brightnessctl}/bin/brightnessctl -d "$SCREEN_DEV" max)
    KBD_MAX=$(${pkgs.brightnessctl}/bin/brightnessctl -d "$KBD_DEV" max)

    # ALS modifier: scales user brightness up/down based on ambient light.
    # Returns a multiplier as percentage (100 = no change).
    # Bright room = boost, dark room = dim.
    get_als_modifier() {
      local als=$1
      if   [ "$als" -le 10 ];  then echo 30
      elif [ "$als" -le 30 ];  then echo 50
      elif [ "$als" -le 60 ];  then echo 70
      elif [ "$als" -le 100 ]; then echo 85
      elif [ "$als" -le 150 ]; then echo 100
      elif [ "$als" -le 200 ]; then echo 115
      elif [ "$als" -le 300 ]; then echo 130
      else echo 150
      fi
    }

    # Keyboard backlight: bright in dark, dim/off in light
    get_kbd_pct() {
      local als=$1
      if   [ "$als" -le 10 ];  then echo 10
      elif [ "$als" -le 30 ];  then echo 8
      elif [ "$als" -le 60 ];  then echo 5
      elif [ "$als" -le 100 ]; then echo 3
      elif [ "$als" -le 150 ]; then echo 1
      else echo 0
      fi
    }

    clamp() {
      local val=$1 min=$2 max=$3
      [ "$val" -lt "$min" ] && val=$min
      [ "$val" -gt "$max" ] && val=$max
      echo "$val"
    }

    # Initialize user brightness to current actual brightness percentage
    current=$(${pkgs.brightnessctl}/bin/brightnessctl -d "$SCREEN_DEV" get)
    user_pct=$(( current * 100 / SCREEN_MAX ))
    echo "$user_pct" > "$USER_PCT_FILE"

    prev_modifier=""
    prev_kbd=""

    while true; do
      als=$(cat "$ALS_PATH" 2>/dev/null || echo -1)
      if [ "$als" -lt 0 ]; then
        sleep 5
        continue
      fi

      modifier=$(get_als_modifier "$als")
      kbd_pct=$(get_kbd_pct "$als")

      # Read user-set brightness (slider/keys write to this file)
      user_pct=$(cat "$USER_PCT_FILE" 2>/dev/null || echo 50)

      # Apply ALS modifier to user brightness
      final=$(( user_pct * modifier / 100 ))
      final=$(clamp "$final" 1 100)

      # Only update screen if ALS modifier changed
      if [ "$modifier" != "$prev_modifier" ]; then
        ${pkgs.brightnessctl}/bin/brightnessctl -d "$SCREEN_DEV" set "''${final}%" -q
        prev_modifier="$modifier"
      fi

      if [ "$kbd_pct" != "$prev_kbd" ]; then
        ${pkgs.brightnessctl}/bin/brightnessctl -d "$KBD_DEV" set "''${kbd_pct}%" -q
        prev_kbd="$kbd_pct"
      fi

      sleep 5
    done
  '';
in
{
  systemd.user.services.auto-brightness = {
    Unit = {
      Description = "Automatic brightness adjustment based on ambient light sensor";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${auto-brightness}";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
