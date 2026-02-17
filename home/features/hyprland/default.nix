{ config, pkgs, lib, ... }:

{
  # Catppuccin Mocha GTK theme
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

  # Force dark mode for GTK apps (pavucontrol, blueman, iwgtk, nautilus, etc.)
  gtk.gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
  gtk.gtk4.extraConfig.gtk-application-prefer-dark-theme = true;

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "catppuccin-mocha-blue-standard";
  };

  # Qt dark mode
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

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    xwayland.enable = true;
    settings = {
      # Monitor configuration (adjust for your setup)
      # Use `hyprctl monitors` to see available monitors
      # Scale 1.5-2 recommended for retina/HiDPI displays
      monitor = [
        ",preferred,auto,1.5"
      ];

      # Environment variables
      env = [
        "XCURSOR_SIZE,36"
        "HYPRCURSOR_SIZE,36"
      ];

      xwayland = {
        force_zero_scaling = true;
      };

      # Input configuration
      input = {
        kb_layout = "us";
        follow_mouse = 1;
        sensitivity = 0;
        touchpad = {
          natural_scroll = true;
        };
      };

      # General appearance
      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";
        layout = "dwindle";
        allow_tearing = false;
      };

      # Decoration (shadows, blur, rounding)
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

      # Animations
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

      # Layout settings
      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      master = {
        new_status = "master";
      };

      # Misc settings
      misc = {
        force_default_wallpaper = 0;
        disable_hyprland_logo = true;
      };

      # Keybindings
      "$mainMod" = "SUPER";
      "$terminal" = "alacritty";
      "$menu" = "wofi --show drun";
      "$browser" = "chromium";

      bind = [
        # Core
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

        # Lock screen
        "$mainMod SHIFT, L, exec, hyprlock"

        # Logout menu
        "$mainMod, Escape, exec, wlogout"

        # Screenshots
        ", Print, exec, grim -g \"$(slurp)\" - | wl-copy"
        "SHIFT, Print, exec, grim - | wl-copy"
        "$mainMod, Print, exec, grim -g \"$(slurp)\" ~/Pictures/Screenshots/$(date +'%Y%m%d_%H%M%S').png"

        # Clipboard history
        "$mainMod, C, exec, cliphist list | wofi --dmenu | cliphist decode | wl-copy"

        # Color picker
        "$mainMod SHIFT, C, exec, hyprpicker -a"

        # Move focus
        "$mainMod, left, movefocus, l"
        "$mainMod, right, movefocus, r"
        "$mainMod, up, movefocus, u"
        "$mainMod, down, movefocus, d"
        "$mainMod, H, movefocus, l"
        "$mainMod, L, movefocus, r"
        "$mainMod, K, movefocus, u"
        "$mainMod, J, movefocus, d"

        # Move windows
        "$mainMod SHIFT, left, movewindow, l"
        "$mainMod SHIFT, right, movewindow, r"
        "$mainMod SHIFT, up, movewindow, u"
        "$mainMod SHIFT, down, movewindow, d"
        "$mainMod SHIFT, H, movewindow, l"
        "$mainMod SHIFT, L, movewindow, r"
        "$mainMod SHIFT, K, movewindow, u"
        "$mainMod SHIFT, J, movewindow, d"

        # Switch workspaces
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

        # Move window to workspace
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

        # Special workspace (scratchpad)
        "$mainMod, S, togglespecialworkspace, magic"
        "$mainMod SHIFT, S, movetoworkspace, special:magic"

        # Scroll through workspaces
        "$mainMod, mouse_down, workspace, e+1"
        "$mainMod, mouse_up, workspace, e-1"

        # Resize mode
        "$mainMod, R, submap, resize"
      ];

      # Mouse bindings
      bindm = [
        "$mainMod, mouse:272, movewindow"
        "$mainMod ALT, mouse:272, resizewindow"
      ];

      # Media/function keys
      bindel = [
        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86MonBrightnessUp, exec, brightnessctl set 5%+ && echo $(( $(brightnessctl -d apple-panel-bl get) * 100 / $(brightnessctl -d apple-panel-bl max) )) > /tmp/auto-brightness-user-pct"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%- && echo $(( $(brightnessctl -d apple-panel-bl get) * 100 / $(brightnessctl -d apple-panel-bl max) )) > /tmp/auto-brightness-user-pct"
      ];

      bindl = [
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioPrev, exec, playerctl previous"
        ", XF86AudioNext, exec, playerctl next"
      ];

      # Startup applications
      exec-once = [
        "waybar"
        "dunst"
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
        "swww-daemon"
        "hypridle"
        "lxqt-policykit-agent"
        "gnome-keyring-daemon --start --components=secrets"
      ];
    };

    # Resize submap
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

  # Hyprlock - screen locker
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

      input-field = [
        {
          size = "200, 50";
          position = "0, -80";
          monitor = "";
          dots_center = true;
          fade_on_empty = false;
          font_color = "rgb(202, 211, 245)";
          inner_color = "rgb(91, 96, 120)";
          outer_color = "rgb(24, 25, 38)";
          outline_thickness = 5;
          placeholder_text = ''<span foreground="##cad3f5">Password...</span>'';
          shadow_passes = 2;
        }
      ];
    };
  };

  # Hypridle - idle daemon
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
          timeout = 300; # 5 minutes
          on-timeout = "brightnessctl -s set 30%";
          on-resume = "brightnessctl -r";
        }
        {
          timeout = 600; # 10 minutes
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 900; # 15 minutes
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        {
          timeout = 1800; # 30 minutes
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };

  # Essential packages
  home.packages = with pkgs; [
    # Screenshot tools
    grim
    slurp
    swappy

    # Clipboard
    wl-clipboard
    cliphist

    # Wallpaper
    swww

    # Utilities
    brightnessctl
    playerctl
    pavucontrol
    blueman

    # Color picker
    hyprpicker

    # Polkit agent
    lxqt.lxqt-policykit

    # File manager
    nautilus

    # Media
    zathura # PDF viewer
    imv # image viewer
    mpv # video player
  ];

  # Create Screenshots directory
  home.file."Pictures/Screenshots/.keep".text = "";
}
