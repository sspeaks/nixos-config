# Plate XIV — Batch 3 system-control backend wrappers (D32)
#
# Five small shell scripts with stable stdout/exit contracts for use as
# Quickshell Process call targets.  All are query-first: they read current
# state and emit it on stdout; callers parse stdout, not exit codes (except
# for the set-* mutators whose only meaningful output is success/failure).
#
# Host facts (D32):
#   Wi-Fi:      iwd daemon, iwctl CLI.  NOT NetworkManager / nmcli.
#   Brightness: brightnessctl, device "apple-panel-bl" (Asahi backlight).
#   Volume:     WirePlumber, wpctl CLI.
#   Bluetooth:  BlueZ, bluetoothctl CLI.
#   Battery:    UPower, upower CLI.
#
# Stdout contracts (machine-readable, one value per line):
#   plate-battery-status  → "PERCENTAGE STATE"  (e.g. "87 charging")
#   plate-brightness-get  → "CURRENT MAX"        (e.g. "420 800")
#   plate-brightness-set  → (no stdout; exits 0 on success)
#   plate-brightness-step → (no stdout; arg: "up" | "down")
#   plate-volume-get      → "VOLUME MUTED"       (e.g. "0.72 0")
#   plate-volume-set      → (no stdout; exits 0 on success)
#   plate-volume-step     → (no stdout; arg: "up" | "down")
#   plate-volume-toggle-mute → (no stdout; exits 0 on success)
#   plate-wifi-status     → "POWERED STATE SSID" (e.g. "1 connected Home Net"
#                                                  or "0 disconnected none")
#   plate-wifi-toggle     → (no stdout; exits 0 on success)
#   plate-wifi-configure  → (launches iwgtk; exits with iwgtk)
#   plate-bluetooth-status → "POWERED CONNECTED"  (e.g. "1 0")
#   plate-bluetooth-toggle → (no stdout; exits 0 on success)
#
# All scripts:
#   - Exit non-zero with a descriptive message on stderr on failure.
#   - Do NOT silently no-op: if the hardware/daemon is absent, say so.
#   - Are designed for poll intervals (2 s) or one-shot mutation calls.
#
# Ownership: Tank (packages/plate-controls/default.nix)

{ pkgs }:

let
  lib = pkgs.lib;

  # Shared helper: writeShellApplication wraps the script in strict bash
  # (-e -u -o pipefail) and validates runtimeInputs are on PATH.
  mkCtl =
    { name
    , runtimeInputs
    , text
    ,
    }:
    pkgs.writeShellApplication {
      inherit name runtimeInputs text;
      meta = {
        description = "Plate XIV system-control backend: ${name}";
        mainProgram = name;
        platforms = lib.platforms.linux;
      };
    };

  brightnessMutation = ''
    plate_brightness_mutate() {
      caller=$1
      value=$2

      if [ -z "''${XDG_RUNTIME_DIR:-}" ]; then
        echo "$caller: XDG_RUNTIME_DIR is unavailable; cannot record user brightness" >&2
        return 1
      fi
      if [ ! -d "$XDG_RUNTIME_DIR" ] || [ ! -w "$XDG_RUNTIME_DIR" ]; then
        echo "$caller: XDG_RUNTIME_DIR is not a writable directory: $XDG_RUNTIME_DIR" >&2
        return 1
      fi

      brightnessctl -d apple-panel-bl set "$value" >/dev/null 2>&1 || {
        echo "$caller: brightnessctl set $value failed" >&2
        return 1
      }

      cur=$(brightnessctl -d apple-panel-bl get 2>/dev/null) || {
        echo "$caller: brightness changed, but reading current brightness failed" >&2
        return 1
      }
      max=$(brightnessctl -d apple-panel-bl max 2>/dev/null) || {
        echo "$caller: brightness changed, but reading maximum brightness failed" >&2
        return 1
      }
      if ! [[ "$cur" =~ ^[0-9]+$ && "$max" =~ ^[0-9]+$ ]] || [ "$max" -eq 0 ]; then
        echo "$caller: brightnessctl returned invalid current/max values: $cur/$max" >&2
        return 1
      fi

      pct=$(( (cur * 100 + max / 2) / max ))
      state_file="$XDG_RUNTIME_DIR/plate-brightness-user-pct"
      printf '%s\n' "$pct" >"$state_file" || {
        echo "$caller: failed to update $state_file" >&2
        return 1
      }
    }
  '';

  volumeMutation = ''
    plate_volume_mutate() {
      caller=$1
      value=$2
      wpctl set-volume --limit 1.0 @DEFAULT_AUDIO_SINK@ "$value" >/dev/null 2>&1 || {
        echo "$caller: wpctl set-volume $value failed" >&2
        return 1
      }
    }
  '';

in
{
  # ── Battery ────────────────────────────────────────────────────────────────
  # stdout: "<percentage_int> <state_lowercase>"
  # state is one of: charging discharging fully-charged unknown
  plate-battery-status = mkCtl {
    name = "plate-battery-status";
    runtimeInputs = [ pkgs.upower ];
    text = ''
      device=$(upower -e | grep -m1 'BAT' || true)
      if [ -z "$device" ]; then
        echo "plate-battery-status: no battery device found via upower" >&2
        exit 1
      fi
      pct=$(upower -i "$device" | awk '/percentage:/ { gsub(/%/,"",$2); print int($2) }')
      state=$(upower -i "$device" | awk '/state:/ { print tolower($2) }')
      printf '%s %s\n' "$pct" "$state"
    '';
  };

  # ── Brightness ─────────────────────────────────────────────────────────────
  # stdout: "<current_int> <max_int>"
  plate-brightness-get = mkCtl {
    name = "plate-brightness-get";
    runtimeInputs = [ pkgs.brightnessctl ];
    text = ''
      cur=$(brightnessctl -d apple-panel-bl get 2>/dev/null) || {
        echo "plate-brightness-get: brightnessctl -d apple-panel-bl get failed" >&2
        exit 1
      }
      max=$(brightnessctl -d apple-panel-bl max 2>/dev/null) || {
        echo "plate-brightness-get: brightnessctl -d apple-panel-bl max failed" >&2
        exit 1
      }
      printf '%s %s\n' "$cur" "$max"
    '';
  };

  # stdin: percentage integer 0-100 as first argument
  # usage: plate-brightness-set <pct>
  plate-brightness-set = mkCtl {
    name = "plate-brightness-set";
    runtimeInputs = [ pkgs.brightnessctl ];
    text = brightnessMutation + ''
      pct=''${1:-}
      if [ -z "$pct" ]; then
        echo "plate-brightness-set: usage: plate-brightness-set <0-100>" >&2
        exit 1
      fi
      if ! [[ "$pct" =~ ^[0-9]+$ ]] || [ "$pct" -gt 100 ]; then
        echo "plate-brightness-set: argument must be integer 0-100, got: $pct" >&2
        exit 1
      fi
      plate_brightness_mutate plate-brightness-set "''${pct}%"
    '';
  };

  # usage: plate-brightness-step up|down (5 percentage-point increments)
  plate-brightness-step = mkCtl {
    name = "plate-brightness-step";
    runtimeInputs = [ pkgs.brightnessctl ];
    text = brightnessMutation + ''
      direction=''${1:-}
      case "$direction" in
        up) value="5%+" ;;
        down) value="5%-" ;;
        *)
          echo "plate-brightness-step: usage: plate-brightness-step up|down" >&2
          exit 1
          ;;
      esac
      plate_brightness_mutate plate-brightness-step "$value"
    '';
  };

  # ── Volume ─────────────────────────────────────────────────────────────────
  # stdout: "<volume_float_0-1> <muted_0_or_1>"
  # e.g.   "0.72 0"  or  "0.50 1"
  plate-volume-get = mkCtl {
    name = "plate-volume-get";
    runtimeInputs = [ pkgs.wireplumber ];
    text = ''
      raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null) || {
        echo "plate-volume-get: wpctl get-volume failed" >&2
        exit 1
      }
      # wpctl output: "Volume: 0.72" or "Volume: 0.50 [MUTED]"
      vol=$(echo "$raw" | awk '{ print $2 }')
      if echo "$raw" | grep -q '\[MUTED\]'; then
        muted=1
      else
        muted=0
      fi
      printf '%s %s\n' "$vol" "$muted"
    '';
  };

  # usage: plate-volume-set <0.0-1.0>
  plate-volume-set = mkCtl {
    name = "plate-volume-set";
    runtimeInputs = [ pkgs.wireplumber ];
    text = volumeMutation + ''
      vol=''${1:-}
      if [ -z "$vol" ]; then
        echo "plate-volume-set: usage: plate-volume-set <0.0-1.0>" >&2
        exit 1
      fi
      if ! [[ "$vol" =~ ^(0(\.[0-9]+)?|1(\.0+)?)$ ]]; then
        echo "plate-volume-set: argument must be a number from 0.0 to 1.0, got: $vol" >&2
        exit 1
      fi
      plate_volume_mutate plate-volume-set "$vol"
    '';
  };

  # usage: plate-volume-step up|down (5 percentage-point increments)
  plate-volume-step = mkCtl {
    name = "plate-volume-step";
    runtimeInputs = [ pkgs.wireplumber ];
    text = volumeMutation + ''
      direction=''${1:-}
      case "$direction" in
        up) value="5%+" ;;
        down) value="5%-" ;;
        *)
          echo "plate-volume-step: usage: plate-volume-step up|down" >&2
          exit 1
          ;;
      esac
      plate_volume_mutate plate-volume-step "$value"
    '';
  };

  plate-volume-toggle-mute = mkCtl {
    name = "plate-volume-toggle-mute";
    runtimeInputs = [ pkgs.wireplumber ];
    text = ''
      wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle >/dev/null 2>&1 || {
        echo "plate-volume-toggle-mute: wpctl set-mute failed" >&2
        exit 1
      }
    '';
  };

  # ── Wi-Fi (iwd) ─────────────────────────────────────────────────────────────
  # stdout: "<powered_0_or_1> <state> <ssid_or_none>"
  # SSID occupies the remainder of the line and may contain spaces.
  # state:  "connected" | "disconnected" | "connecting" | "unknown"
  # e.g.    "1 connected Home Net" or "0 disconnected none"
  plate-wifi-status = mkCtl {
    name = "plate-wifi-status";
    runtimeInputs = [ pkgs.iwd ];
    text = ''
      # iwctl station wlan0 show exits 0 even when iwd is stopped; detect absence
      # by whether /run/iwd/ socket directory exists (iwd sets it up at start).
      if [ ! -d /run/iwd ]; then
        echo "plate-wifi-status: iwd not running (/run/iwd absent)" >&2
        exit 1
      fi
      device=$(iwctl device wlan0 show 2>/dev/null) || {
        echo "plate-wifi-status: iwctl device wlan0 show failed" >&2
        exit 1
      }
      powered=$(echo "$device" | awk '/Powered/ { print tolower($2); exit }')
      case "$powered" in
        on) powered=1 ;;
        off)
          printf '0 disconnected none\n'
          exit 0
          ;;
        *)
          echo "plate-wifi-status: could not determine wlan0 radio power" >&2
          exit 1
          ;;
      esac

      raw=$(iwctl station wlan0 show 2>/dev/null) || {
        echo "plate-wifi-status: wlan0 is powered, but station status failed" >&2
        exit 1
      }
      state=$(echo "$raw" | awk '/State/ { print tolower($2); exit }')
      ssid=$(echo "$raw" | awk '
        /Connected network/ {
          for (i = 3; i <= NF; i++) {
            printf "%s%s", (i == 3 ? "" : " "), $i
          }
          print ""
          exit
        }
      ')
      [ -z "$state" ] && state="unknown"
      [ -z "$ssid"  ] && ssid="none"
      printf '%s %s %s\n' "$powered" "$state" "$ssid"
    '';
  };

  # Toggle: if powered off → on; if on → off (uses iwctl device property).
  # Quickshell reads plate-wifi-status to decide which direction to show.
  plate-wifi-toggle = mkCtl {
    name = "plate-wifi-toggle";
    runtimeInputs = [ pkgs.iwd ];
    text = ''
      if [ ! -d /run/iwd ]; then
        echo "plate-wifi-toggle: iwd not running (/run/iwd absent)" >&2
        exit 1
      fi
      powered=$(iwctl device wlan0 show 2>/dev/null \
                | awk '/Powered/ { print tolower($2); exit }') || {
        echo "plate-wifi-toggle: iwctl device wlan0 show failed" >&2
        exit 1
      }
      if [ "$powered" = "on" ]; then
        iwctl device wlan0 set-property Powered off >/dev/null 2>&1 || {
          echo "plate-wifi-toggle: failed to power off wlan0" >&2
          exit 1
        }
      else
        iwctl device wlan0 set-property Powered on >/dev/null 2>&1 || {
          echo "plate-wifi-toggle: failed to power on wlan0" >&2
          exit 1
        }
      fi
    '';
  };

  plate-wifi-configure = mkCtl {
    name = "plate-wifi-configure";
    runtimeInputs = [ pkgs.iwgtk ];
    text = ''
      if [ "$#" -ne 0 ]; then
        echo "plate-wifi-configure: usage: plate-wifi-configure" >&2
        exit 1
      fi
      exec iwgtk
    '';
  };

  # ── Bluetooth ───────────────────────────────────────────────────────────────
  # stdout: "<powered_0_or_1> <connected_count_int>"
  # e.g.   "1 2"  (adapter on, 2 devices connected)
  #         "0 0"  (adapter off)
  plate-bluetooth-status = mkCtl {
    name = "plate-bluetooth-status";
    runtimeInputs = [ pkgs.bluez ];
    text = ''
      powered_line=$(bluetoothctl show 2>/dev/null | grep 'Powered:') || {
        echo "plate-bluetooth-status: bluetoothctl show failed" >&2
        exit 1
      }
      if echo "$powered_line" | grep -q 'yes'; then
        powered=1
      else
        powered=0
      fi
      if [ "$powered" -eq 1 ]; then
        connected=$(bluetoothctl devices Connected 2>/dev/null | wc -l)
      else
        connected=0
      fi
      printf '%s %s\n' "$powered" "$connected"
    '';
  };

  plate-bluetooth-toggle = mkCtl {
    name = "plate-bluetooth-toggle";
    runtimeInputs = [
      pkgs.bluez
      pkgs.util-linux
    ];
    text = ''
      powered_line=$(bluetoothctl show 2>/dev/null | grep 'Powered:') || {
        echo "plate-bluetooth-toggle: bluetoothctl show failed" >&2
        exit 1
      }
      if echo "$powered_line" | grep -q 'yes'; then
        bluetoothctl power off >/dev/null 2>&1 || {
          echo "plate-bluetooth-toggle: bluetoothctl power off failed" >&2
          exit 1
        }
      else
        rfkill unblock bluetooth >/dev/null 2>&1 || {
          echo "plate-bluetooth-toggle: failed to clear Bluetooth rfkill soft block" >&2
          exit 1
        }
        bluetoothctl power on >/dev/null 2>&1 || {
          echo "plate-bluetooth-toggle: rfkill unblocked, but bluetoothctl power on failed" >&2
          exit 1
        }
      fi
    '';
  };
}
