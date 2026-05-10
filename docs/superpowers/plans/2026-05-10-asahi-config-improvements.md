# Asahi Configuration Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve the Asahi NixOS configuration's stability, visual consistency, and maintainability while preserving familiar physical key chords except for the explicitly approved wlogout hibernate removal.

**Architecture:** Add shared theme and wallpaper constants first, then split `home/features/hyprland/default.nix` into focused modules that import those constants. Apply host-level stability fixes, home-manager service ownership fixes, brightness coordination, visual polish, and the approved wlogout/zsh cleanup through those focused files.

**Tech Stack:** Nix flakes, NixOS modules, Home Manager modules, Hyprland, Hyprlock, Hypridle, Waybar, Dunst, SDDM, zsh.

---

## File structure

- Create `home/features/theme/palette.nix`: shared Catppuccin Mocha colors, font names, and helper functions for CSS/RGBA strings.
- Create `hosts/asahi/paths.nix`: shared host-specific paths, initially the Bing wallpaper path.
- Modify `hosts/asahi/default.nix`: define `_module.args.asahiPaths` and import host modules as before.
- Modify `hosts/asahi/bing-wallpaper.nix`: use `asahiPaths.wallpaper` for the generated image path and add curl retry behavior.
- Modify `hosts/asahi/hardware.nix`: set `boot.loader.systemd-boot.configurationLimit = 5`.
- Modify `hosts/asahi/desktop.nix`: pass `asahiPaths` into Home Manager, use `asahiPaths.wallpaper`, add explicit XDG portal routing, and align SDDM theme config.
- Modify `hosts/asahi/networking.nix`: set `networking.useDHCP = false` and keep iwd network configuration enabled.
- Create `home/features/hyprland/theme.nix`: GTK, Qt, cursor, and theme-related settings.
- Create `home/features/hyprland/config.nix`: Hyprland monitor, input, general appearance, decoration, animation, layout, misc, and layer rules.
- Create `home/features/hyprland/keybindings.nix`: all Hyprland key chords, preserving physical chords and changing only brightness command targets.
- Create `home/features/hyprland/startup.nix`: Hyprland `exec-once` entries, without `dunst` and `hypridle`.
- Create `home/features/hyprland/lock-idle.nix`: Hyprlock labels/input colors and Hypridle sentinel-based dimming.
- Create `home/features/hyprland/packages.nix`: Hyprland-related user packages and the Dolphin wrapper.
- Create `home/features/hyprland/kde.nix`: KDE menu, `kdeglobals`, Dolphin desktop entry, and MIME associations moved from the current monolith.
- Modify `home/features/hyprland/default.nix`: replace the monolith with imports of the focused modules.
- Modify `home/features/hyprland/auto-brightness.nix`: skip screen brightness writes while the Hypridle dimming sentinel exists.
- Modify `hosts/asahi/waybar.nix`: import shared palette values, style `#window`, use shared wallpaper-independent theme constants, and target `apple-panel-bl` in brightness commands.
- Modify `home/features/dunst/default.nix`: import shared palette values and apply transparency/progress styling.
- Modify `home/features/zsh/default.nix`: make the WSL-specific `pbpaste` alias fail explicitly outside WSL instead of exposing a broken command.
- Modify `home/features/wlogout/default.nix`: remove the hibernate action and keybind.
- Modify docs only if implementation diverges from `docs/superpowers/specs/2026-05-10-asahi-config-improvements-design.md`.

## Task 1: Add shared theme and wallpaper constants

**Files:**
- Create: `home/features/theme/palette.nix`
- Create: `hosts/asahi/paths.nix`
- Modify: `hosts/asahi/default.nix`

- [ ] **Step 1: Create the shared palette file**

Create `home/features/theme/palette.nix` with exactly this shape:

```nix
{
  mocha = {
    rosewater = "#f5e0dc";
    flamingo = "#f2cdcd";
    pink = "#f5c2e7";
    mauve = "#cba6f7";
    red = "#f38ba8";
    maroon = "#eba0ac";
    peach = "#fab387";
    yellow = "#f9e2af";
    green = "#a6e3a1";
    teal = "#94e2d5";
    sky = "#89dceb";
    sapphire = "#74c7ec";
    blue = "#89b4fa";
    lavender = "#b4befe";
    text = "#cdd6f4";
    subtext1 = "#bac2de";
    subtext0 = "#a6adc8";
    overlay2 = "#9399b2";
    overlay1 = "#7f849c";
    overlay0 = "#6c7086";
    surface2 = "#585b70";
    surface1 = "#45475a";
    surface0 = "#313244";
    base = "#1e1e2e";
    mantle = "#181825";
    crust = "#11111b";
  };

  fonts = {
    mono = "JetBrainsMono Nerd Font";
    monoCss = ''"JetBrainsMono Nerd Font", "JetBrains Mono Nerd Font", "JetBrains Mono", "Symbols Nerd Font", "Font Awesome 6 Free", monospace'';
    sddm = "JetBrains Mono";
  };

  stripHash = color: builtins.substring 1 6 color;
  rgba = color: alpha: "rgba(${builtins.substring 1 6 color}${alpha})";
  rgb = color: "rgb(${builtins.substring 1 6 color})";
}
```

- [ ] **Step 2: Create the shared Asahi paths file**

Create `hosts/asahi/paths.nix`:

```nix
{
  wallpaper = "/var/lib/bing-wallpaper/wallpaper.jpg";
}
```

- [ ] **Step 3: Wire `asahiPaths` into the host**

In `hosts/asahi/default.nix`, add a `let` binding and `_module.args` so imported host modules can share the wallpaper path:

Wrap the existing file in a `let` binding while preserving its current function arguments:

```nix
{ config, pkgs, lib, inputs, ... }:

let
  asahiPaths = import ./paths.nix;
in
{
  imports = [
    ../common/global
    ../common/users/sspeaks
    ./hardware-config.nix
    ./hardware.nix
    ./networking.nix
    ./desktop.nix
    ./bluetooth.nix
    ./services.nix
    ./bing-wallpaper.nix
  ];

  _module.args = {
    inherit asahiPaths;
  };

  # ...keep the existing zram and other host settings below unchanged...
}
```

If the existing file already has settings below `imports`, preserve them exactly and only add the `let` binding plus `_module.args`.

- [ ] **Step 4: Format and inspect**

Run:

```bash
cd /home/sspeaks/nixos-config
nix fmt
git --no-pager diff -- home/features/theme/palette.nix hosts/asahi/paths.nix hosts/asahi/default.nix
```

Expected: formatting succeeds; the diff only adds shared constants and module args.

- [ ] **Step 5: Commit**

```bash
cd /home/sspeaks/nixos-config
git add home/features/theme/palette.nix hosts/asahi/paths.nix hosts/asahi/default.nix
git commit -m $'Add shared Asahi theme constants\n\nCo-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

## Task 2: Apply host-level stability fixes

**Files:**
- Modify: `hosts/asahi/hardware.nix`
- Modify: `hosts/asahi/desktop.nix`
- Modify: `hosts/asahi/networking.nix`
- Modify: `hosts/asahi/bing-wallpaper.nix`

- [ ] **Step 1: Cap systemd-boot generations**

In `hosts/asahi/hardware.nix`, change the boot loader section to:

```nix
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 5;
  };
  boot.loader.efi.canTouchEfiVariables = false;
```

- [ ] **Step 2: Make portal routing explicit and style SDDM**

Change the function header in `hosts/asahi/desktop.nix` to include `asahiPaths`:

```nix
{ config, pkgs, lib, asahiPaths, ... }:
```

Replace the `xdg.portal` block with:

```nix
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
    config.common = {
      default = [
        "hyprland"
        "gtk"
      ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
    };
  };
```

Add Home Manager extra special args so `asahiPaths` is also available to imported home-manager modules:

```nix
  home-manager.extraSpecialArgs = {
    inherit asahiPaths;
  };
```

Place this near the existing `home-manager.backupFileExtension` and `home-manager.useUserPackages` settings.

Change the SDDM theme override to:

```nix
    (where-is-my-sddm-theme.override {
      themeConfig.General = {
        background = asahiPaths.wallpaper;
        backgroundMode = "fill";
        quote = "";
        accentColor = "#89b4fa";
        font = "JetBrains Mono";
        fontSize = 14;
      };
    })
```

- [ ] **Step 3: Let iwd own DHCP/network configuration**

In `hosts/asahi/networking.nix`, extend the `networking = { ... };` block:

```nix
  networking = {
    hostName = "asahi-mpb";
    useDHCP = false;
    firewall.enable = true;
    firewall.allowedUDPPorts = [ 5353 ];
  };
```

Keep `networking.wireless.iwd.enable = true` and `settings.General.EnableNetworkConfiguration = true`.

- [ ] **Step 4: Use the shared wallpaper path and add curl retries**

Change the function header in `hosts/asahi/bing-wallpaper.nix` to include `asahiPaths`:

```nix
{ config, pkgs, lib, asahiPaths, ... }:
```

Replace hardcoded `/var/lib/bing-wallpaper/wallpaper.jpg` occurrences with `${asahiPaths.wallpaper}` or shell variable usage. The service script should keep the last good image on transient failures and use curl retries:

```nix
      script = ''
        set -euo pipefail

        wallpaper_dir="$(${pkgs.coreutils}/bin/dirname ${lib.escapeShellArg asahiPaths.wallpaper})"
        wallpaper_tmp="${lib.escapeShellArg asahiPaths.wallpaper}.tmp"
        ${pkgs.coreutils}/bin/mkdir -p "$wallpaper_dir"

        metadata="$(${pkgs.curl}/bin/curl --fail --silent --show-error --location --retry 3 --retry-delay 2 'https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=en-US')"
        url_path="$(printf '%s' "$metadata" | ${pkgs.jq}/bin/jq -r '.images[0].url')"
        image_url="https://www.bing.com$url_path"

        ${pkgs.curl}/bin/curl --fail --silent --show-error --location --retry 3 --retry-delay 2 "$image_url" --output "$wallpaper_tmp"
        ${pkgs.coreutils}/bin/mv "$wallpaper_tmp" ${lib.escapeShellArg asahiPaths.wallpaper}
      '';
```

- [ ] **Step 5: Format and evaluate the Asahi config**

Run:

```bash
cd /home/sspeaks/nixos-config
nix fmt
nix eval .#nixosConfigurations.asahi.config.networking.useDHCP
nix eval .#nixosConfigurations.asahi.config.boot.loader.systemd-boot.configurationLimit
```

Expected:

```text
false
5
```

- [ ] **Step 6: Commit**

```bash
cd /home/sspeaks/nixos-config
git add hosts/asahi/hardware.nix hosts/asahi/desktop.nix hosts/asahi/networking.nix hosts/asahi/bing-wallpaper.nix
git commit -m $'Fix Asahi host stability settings\n\nCo-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

## Task 3: Split Hyprland into focused modules

**Files:**
- Create: `home/features/hyprland/theme.nix`
- Create: `home/features/hyprland/config.nix`
- Create: `home/features/hyprland/keybindings.nix`
- Create: `home/features/hyprland/startup.nix`
- Create: `home/features/hyprland/lock-idle.nix`
- Create: `home/features/hyprland/packages.nix`
- Create: `home/features/hyprland/kde.nix`
- Modify: `home/features/hyprland/default.nix`

- [ ] **Step 1: Create `theme.nix`**

Move the GTK, Qt, cursor, and `services.hyprpaper.enable = false` settings from the old `default.nix` into `home/features/hyprland/theme.nix`. Import the palette at the top:

```nix
{ pkgs, ... }:

let
  palette = import ../theme/palette.nix;
in
{
  services.hyprpaper.enable = false;

  gtk = {
    enable = true;
    theme = {
      name = "catppuccin-mocha-blue-standard";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "blue" ];
        variant = "mocha";
      };
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.catppuccin-papirus-folders.override {
        accent = "blue";
        flavor = "mocha";
      };
    };
  };

  gtk.gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
  gtk.gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
  gtk.gtk4.theme = null;

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "catppuccin-mocha-blue-standard";
  };

  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style.name = "adwaita-dark";
  };

  home.pointerCursor = {
    name = "catppuccin-mocha-blue-cursors";
    package = pkgs.catppuccin-cursors.mochaBlue;
    size = 36;
    gtk.enable = true;
  };
}
```

- [ ] **Step 2: Create `config.nix`**

Move Hyprland settings from monitor through misc into `home/features/hyprland/config.nix`, and apply the Catppuccin border and layer-rule changes:

```nix
{ ... }:

let
  palette = import ../theme/palette.nix;
  mocha = palette.mocha;
in
{
  wayland.windowManager.hyprland = {
    enable = true;
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
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = "${palette.rgba mocha.blue "ee"} ${palette.rgba mocha.mauve "ee"} 45deg";
        "col.inactive_border" = palette.rgba mocha.overlay0 "aa";
        layout = "dwindle";
        allow_tearing = false;
      };

      decoration = {
        rounding = 10;
        blur = {
          enabled = true;
          size = 3;
          passes = 1;
          vibrancy = 0.1696;
        };
        shadow = {
          enabled = true;
          range = 4;
          render_power = 3;
          color = "rgba(1a1a1aee)";
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
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, easeOutQuint, slide"
        ];
      };

      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      master.new_status = "master";

      misc = {
        force_default_wallpaper = 0;
        disable_hyprland_logo = true;
      };

      layerrule = [
        "blur, waybar"
        "blur, dunst"
        "ignorezero, waybar"
        "ignorezero, dunst"
      ];
    };
  };
}
```

- [ ] **Step 3: Create `keybindings.nix`**

Move all keybinding settings from the old `default.nix` into `home/features/hyprland/keybindings.nix`. Preserve physical chords exactly, but update brightness commands to use `-d apple-panel-bl`:

```nix
{ ... }:

{
  wayland.windowManager.hyprland = {
    settings = {
      "$mainMod" = "SUPER";
      "$terminal" = "alacritty";
      "$menu" = "wofi --show drun";
      "$browser" = "chromium";

      bind = [
        "$mainMod, Return, exec, $terminal"
        "$mainMod, B, exec, $browser"
        "$mainMod, Q, killactive,"
        "$mainMod SHIFT, E, exit,"
        "$mainMod, E, exec, nautilus"
        "$mainMod, V, togglefloating,"
        "$mainMod, D, exec, $menu"
        "$mainMod, SPACE, exec, $menu"
        "$mainMod, P, pseudo,"
        "$mainMod, T, togglesplit,"
        "$mainMod, F, fullscreen,"
        "$mainMod SHIFT, L, exec, hyprlock"
        "$mainMod, Escape, exec, wlogout"
        ", Print, exec, grim -g \"$(slurp)\" - | wl-copy"
        "SHIFT, Print, exec, grim - | wl-copy"
        "$mainMod, Print, exec, grim -g \"$(slurp)\" ~/Pictures/Screenshots/$(date +'%Y%m%d_%H%M%S').png"
        "$mainMod, C, exec, cliphist list | wofi --dmenu | cliphist decode | wl-copy"
        "$mainMod SHIFT, C, exec, hyprpicker -a"
        "$mainMod, left, movefocus, l"
        "$mainMod, right, movefocus, r"
        "$mainMod, up, movefocus, u"
        "$mainMod, down, movefocus, d"
        "$mainMod, H, movefocus, l"
        "$mainMod, L, movefocus, r"
        "$mainMod, K, movefocus, u"
        "$mainMod, J, movefocus, d"
        "$mainMod SHIFT, left, movewindow, l"
        "$mainMod SHIFT, right, movewindow, r"
        "$mainMod SHIFT, up, movewindow, u"
        "$mainMod SHIFT, down, movewindow, d"
        "$mainMod SHIFT, H, movewindow, l"
        "$mainMod SHIFT, L, movewindow, r"
        "$mainMod SHIFT, K, movewindow, u"
        "$mainMod SHIFT, J, movewindow, d"
        "$mainMod, 1, workspace, 1"
        "$mainMod, 2, workspace, 2"
        "$mainMod, 3, workspace, 3"
        "$mainMod, 4, workspace, 4"
        "$mainMod, 5, workspace, 5"
        "$mainMod, 6, workspace, 6"
        "$mainMod, 7, workspace, 7"
        "$mainMod, 8, workspace, 8"
        "$mainMod, 9, workspace, 9"
        "$mainMod, 0, workspace, 10"
        "$mainMod SHIFT, 1, movetoworkspace, 1"
        "$mainMod SHIFT, 2, movetoworkspace, 2"
        "$mainMod SHIFT, 3, movetoworkspace, 3"
        "$mainMod SHIFT, 4, movetoworkspace, 4"
        "$mainMod SHIFT, 5, movetoworkspace, 5"
        "$mainMod SHIFT, 6, movetoworkspace, 6"
        "$mainMod SHIFT, 7, movetoworkspace, 7"
        "$mainMod SHIFT, 8, movetoworkspace, 8"
        "$mainMod SHIFT, 9, movetoworkspace, 9"
        "$mainMod SHIFT, 0, movetoworkspace, 10"
        "$mainMod, S, togglespecialworkspace, magic"
        "$mainMod SHIFT, S, movetoworkspace, special:magic"
        "$mainMod, mouse_down, workspace, e+1"
        "$mainMod, mouse_up, workspace, e-1"
        "$mainMod, R, submap, resize"
      ];

      bindm = [
        "$mainMod, mouse:272, movewindow"
        "$mainMod ALT, mouse:272, resizewindow"
      ];

      bindel = [
        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86MonBrightnessUp, exec, brightnessctl -d apple-panel-bl set 5%+ && echo $(( $(brightnessctl -d apple-panel-bl get) * 100 / $(brightnessctl -d apple-panel-bl max) )) > /tmp/auto-brightness-user-pct"
        ", XF86MonBrightnessDown, exec, brightnessctl -d apple-panel-bl set 5%- && echo $(( $(brightnessctl -d apple-panel-bl get) * 100 / $(brightnessctl -d apple-panel-bl max) )) > /tmp/auto-brightness-user-pct"
      ];

      bindl = [
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioPrev, exec, playerctl previous"
        ", XF86AudioNext, exec, playerctl next"
      ];
    };

    extraConfig = ''
      submap = resize
      binde = , right, resizeactive, 10 0
      binde = , left, resizeactive, -10 0
      binde = , up, resizeactive, 0 -10
      binde = , down, resizeactive, 0 10
      binde = , l, resizeactive, 10 0
      binde = , h, resizeactive, -10 0
      binde = , k, resizeactive, 0 -10
      binde = , j, resizeactive, 0 10
      bind = , escape, submap, reset
      bind = , Return, submap, reset
      submap = reset
    '';
  };
}
```

- [ ] **Step 4: Create `startup.nix`**

Create `home/features/hyprland/startup.nix`:

```nix
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
```

- [ ] **Step 5: Create `lock-idle.nix`**

Create `home/features/hyprland/lock-idle.nix` with Hyprlock labels and Hypridle sentinel dimming:

```nix
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
          placeholder_text = ''<span foreground="${mocha.text}">Password...</span>'';
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
```

- [ ] **Step 6: Move packages and KDE support**

Create `home/features/hyprland/packages.nix` by moving the `home.packages` list from the old `default.nix`. Keep the Dolphin wrapper exactly as it exists.

Create `home/features/hyprland/kde.nix` by moving the `xdg.configFile."menus/applications.menu".text`, `xdg.configFile."kdeglobals".text`, Dolphin desktop entry, and MIME default sections from the old `default.nix`.

- [ ] **Step 7: Replace `default.nix` with imports**

Replace `home/features/hyprland/default.nix` with:

```nix
{
  imports = [
    ./theme.nix
    ./config.nix
    ./keybindings.nix
    ./startup.nix
    ./lock-idle.nix
    ./packages.nix
    ./kde.nix
  ];
}
```

- [ ] **Step 8: Verify the split preserves expected Hyprland config**

Run:

```bash
cd /home/sspeaks/nixos-config
nix fmt
nix eval .#nixosConfigurations.asahi.config.home-manager.users.sspeaks.wayland.windowManager.hyprland.settings.\"$mainMod\"
nix eval .#nixosConfigurations.asahi.config.home-manager.users.sspeaks.services.hypridle.enable
nix eval .#nixosConfigurations.asahi.config.home-manager.users.sspeaks.programs.hyprlock.enable
```

Expected:

```text
"SUPER"
true
true
```

- [ ] **Step 9: Commit**

```bash
cd /home/sspeaks/nixos-config
git add home/features/hyprland/default.nix home/features/hyprland/theme.nix home/features/hyprland/config.nix home/features/hyprland/keybindings.nix home/features/hyprland/startup.nix home/features/hyprland/lock-idle.nix home/features/hyprland/packages.nix home/features/hyprland/kde.nix
git commit -m $'Split Hyprland home configuration\n\nCo-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

## Task 4: Coordinate auto-brightness and apply app polish

**Files:**
- Modify: `home/features/hyprland/auto-brightness.nix`
- Modify: `hosts/asahi/waybar.nix`
- Modify: `home/features/dunst/default.nix`

- [ ] **Step 1: Add the Hypridle dimming sentinel to auto-brightness**

In `home/features/hyprland/auto-brightness.nix`, add:

```sh
    DIMMING_SENTINEL="''${XDG_RUNTIME_DIR:-/tmp}/hypridle-dimming"
```

after `USER_PCT_FILE=...`.

Replace the screen update block with:

```sh
      # Only update screen if ALS modifier changed and Hypridle is not dimming.
      if [ "$modifier" != "$prev_modifier" ] && [ ! -e "$DIMMING_SENTINEL" ]; then
        ${pkgs.brightnessctl}/bin/brightnessctl -d "$SCREEN_DEV" set "''${final}%" -q
        prev_modifier="$modifier"
      elif [ -e "$DIMMING_SENTINEL" ]; then
        prev_modifier="$modifier"
      fi
```

- [ ] **Step 2: Style Waybar `#window` and target screen brightness**

In `hosts/asahi/waybar.nix`, import the palette:

```nix
let
  palette = import ../../home/features/theme/palette.nix;
  mocha = palette.mocha;
in
```

Use `${palette.fonts.monoCss}` for the CSS `font-family`.

Replace the `#window` CSS block with:

```css
      #window {
        color: ${mocha.text};
        padding: 4px 15px;
        margin: 5px 3px;
        background: rgba(30, 30, 46, 0.6);
        border-radius: 10px;
      }
```

Update the backlight actions:

```nix
        on-click = "brightnessctl -d apple-panel-bl set 100% && echo 100 > /tmp/auto-brightness-user-pct";
        on-click-right = "brightnessctl -d apple-panel-bl set 30% && echo 30 > /tmp/auto-brightness-user-pct";
        on-scroll-up = "brightnessctl -d apple-panel-bl set 5%+ && echo $(( $(brightnessctl -d apple-panel-bl get) * 100 / $(brightnessctl -d apple-panel-bl max) )) > /tmp/auto-brightness-user-pct";
        on-scroll-down = "brightnessctl -d apple-panel-bl set 5%- && echo $(( $(brightnessctl -d apple-panel-bl get) * 100 / $(brightnessctl -d apple-panel-bl max) )) > /tmp/auto-brightness-user-pct";
```

- [ ] **Step 3: Tune Dunst transparency and palette use**

In `home/features/dunst/default.nix`, import the palette:

```nix
{ ... }:

let
  palette = import ../theme/palette.nix;
  mocha = palette.mocha;
in
```

Then set:

```nix
        transparency = 10;
        progress_bar_corner_radius = 5;
        frame_color = mocha.blue;
        font = "${palette.fonts.mono} 10";
```

Use `mocha.base`, `mocha.text`, `mocha.blue`, and `mocha.red` for urgency colors.

- [ ] **Step 4: Evaluate polished settings**

Run:

```bash
cd /home/sspeaks/nixos-config
nix fmt
nix eval .#nixosConfigurations.asahi.config.home-manager.users.sspeaks.services.dunst.settings.global.transparency
nix eval .#nixosConfigurations.asahi.config.home-manager.users.sspeaks.programs.waybar.settings.mainBar.backlight.on-click
```

Expected output includes:

```text
10
"brightnessctl -d apple-panel-bl set 100% && echo 100 > /tmp/auto-brightness-user-pct"
```

- [ ] **Step 5: Commit**

```bash
cd /home/sspeaks/nixos-config
git add home/features/hyprland/auto-brightness.nix hosts/asahi/waybar.nix home/features/dunst/default.nix
git commit -m $'Polish Asahi desktop services\n\nCo-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

## Task 5: Remove unsupported hibernate and guard WSL alias

**Files:**
- Modify: `home/features/wlogout/default.nix`
- Modify: `home/features/zsh/default.nix`

- [ ] **Step 1: Remove the wlogout hibernate action**

In `home/features/wlogout/default.nix`, remove the hibernate layout entry that executes `systemctl hibernate` and remove the corresponding `h` keybind. Keep lock, logout, shutdown, suspend, and reboot actions unchanged.

- [ ] **Step 2: Guard the WSL-only `pbpaste` alias**

In `home/features/zsh/default.nix`, keep `shellAliases` as a plain attribute set and replace the current `pbpaste` value with a runtime-safe shell alias:

```nix
    shellAliases = {
      ls = "ls --color=auto -F";
      cat = "${pkgs.bat}/bin/bat";
      pbpaste = "if [ -e /proc/sys/fs/binfmt_misc/WSLInterop ]; then wslpath -u $(/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -command '$f=New-TemporaryFile;(Get-Clipboard -Format image).save($f.FullName);echo $f.FullName') | tr -d '\\r\\n'; else echo 'pbpaste is only available under WSL' >&2; false; fi";
    };
```

This preserves the alias for WSL users but makes the Asahi failure explicit instead of exposing a broken command.

- [ ] **Step 3: Evaluate the menu and alias**

Run:

```bash
cd /home/sspeaks/nixos-config
nix fmt
nix eval .#nixosConfigurations.asahi.config.home-manager.users.sspeaks.programs.wlogout.layout --json | grep -F hibernate
nix eval .#nixosConfigurations.asahi.config.home-manager.users.sspeaks.programs.zsh.shellAliases.pbpaste
```

Expected: the `grep -F hibernate` command exits with status 1 and prints nothing; the `pbpaste` alias includes `pbpaste is only available under WSL`.

- [ ] **Step 4: Commit**

```bash
cd /home/sspeaks/nixos-config
git add home/features/wlogout/default.nix home/features/zsh/default.nix
git commit -m $'Clean up host-specific shell and power actions\n\nCo-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

## Task 6: Final validation and diff audit

**Files:**
- Inspect all modified files.

- [ ] **Step 1: Run full formatting**

```bash
cd /home/sspeaks/nixos-config
nix fmt
```

Expected: command exits successfully.

- [ ] **Step 2: Run flake checks**

```bash
cd /home/sspeaks/nixos-config
nix flake check
```

Expected: command exits successfully.

- [ ] **Step 3: Build the Asahi toplevel**

Prefer `nom` when available:

```bash
cd /home/sspeaks/nixos-config
if command -v nom >/dev/null 2>&1; then
  nom build .#nixosConfigurations.asahi.config.system.build.toplevel
else
  nix build .#nixosConfigurations.asahi.config.system.build.toplevel
fi
```

Expected: command exits successfully and leaves/updates `result`.

- [ ] **Step 4: Audit keybinding preservation**

Run:

```bash
cd /home/sspeaks/nixos-config
git --no-pager show HEAD~5:home/features/hyprland/default.nix > /tmp/asahi-hyprland-before.nix
grep -E '^[[:space:]]*".*, .*, (exec|workspace|movetoworkspace|movefocus|movewindow|submap|killactive|exit|togglefloating|pseudo|togglesplit|fullscreen)' /tmp/asahi-hyprland-before.nix > /tmp/asahi-keybinds-before.txt
grep -R -E '^[[:space:]]*".*, .*, (exec|workspace|movetoworkspace|movefocus|movewindow|submap|killactive|exit|togglefloating|pseudo|togglesplit|fullscreen)' home/features/hyprland/keybindings.nix > /tmp/asahi-keybinds-after.txt
diff -u /tmp/asahi-keybinds-before.txt /tmp/asahi-keybinds-after.txt || true
```

Expected: differences are limited to file path prefixes and the two approved brightness command target changes.

- [ ] **Step 5: Inspect final status**

```bash
cd /home/sspeaks/nixos-config
git --no-pager status --short
git --no-pager log --oneline -6
```

Expected: working tree is clean after all task commits; recent commits include the spec plus task commits.
