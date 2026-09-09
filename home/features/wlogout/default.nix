{ config, pkgs, lib, ... }:

let
  plate = import ../theme/plate.nix;

  # wlogout focuses the window but no child. Focus the first button on open
  # so arrow keys work without first pressing Tab or using the pointer.
  # Upstream: https://github.com/ArtsyMacaw/wlogout/blob/1.2.2/main.c
  wlogoutPatched = pkgs.wlogout.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace main.c \
        --replace-fail \
          'gtk_widget_show_all(gtk_window);' \
          'gtk_widget_show_all(gtk_window); gtk_widget_child_focus(gtk_window, GTK_DIR_TAB_FORWARD);'
    '';
  });
in
{
  programs.wlogout = {
    enable = true;
    package = wlogoutPatched;
    layout = [
      {
        label = "lock";
        action = "hyprlock";
        text = "Lock";
        keybind = "l";
      }
      {
        label = "logout";
        # packages/plate-wrappers selects the active compositor.
        action = "plate-logout";
        text = "Logout";
        keybind = "e";
      }
      {
        label = "suspend";
        action = "systemctl suspend";
        text = "Suspend";
        keybind = "u";
      }
      {
        label = "shutdown";
        action = "systemctl poweroff";
        text = "Shutdown";
        keybind = "s";
      }
      {
        label = "reboot";
        action = "systemctl reboot";
        text = "Reboot";
        keybind = "r";
      }
    ];
    style = ''
      * {
        background-image: none;
        font-family: ${plate.type.monoCss};
      }

      window {
        background-color: ${plate.cssRgba plate.bg.void "0.85"};
      }

      button {
        color: ${plate.fg.primary};
        background-color: ${plate.cssRgba plate.bg.panel "0.80"};
        border-style: solid;
        border-width: 2px;
        border-color: ${plate.line.edge};
        background-repeat: no-repeat;
        background-position: center;
        background-size: 25%;
        border-radius: ${plate.geometry.radius};
        margin: 10px;
        transition: all 0.3s ease;
        outline: none;
      }

      /* The inset outline keeps keyboard focus visible when :hover overrides
         the border color. */
      button:focus {
        background-color: ${plate.cssRgba plate.bg.inset "0.90"};
        border-color: ${plate.state.focus};
        box-shadow: inset 0 0 0 2px ${plate.state.focus};
        outline: none;
      }

      button:hover {
        background-color: ${plate.cssRgba plate.bg.inset "0.90"};
        border-color: ${plate.line.rule};
        outline: none;
      }

      button:active {
        background-color: ${plate.cssRgba plate.bg.panel "0.70"};
        border-color: ${plate.state.focus};
        outline: none;
      }

      #lock {
        background-image: image(url("${wlogoutPatched}/share/wlogout/icons/lock.png"));
      }

      #logout {
        background-image: image(url("${wlogoutPatched}/share/wlogout/icons/logout.png"));
      }

      #suspend {
        background-image: image(url("${wlogoutPatched}/share/wlogout/icons/suspend.png"));
      }

      #shutdown {
        background-image: image(url("${wlogoutPatched}/share/wlogout/icons/shutdown.png"));
      }

      #reboot {
        background-image: image(url("${wlogoutPatched}/share/wlogout/icons/reboot.png"));
      }
    '';
  };
}
