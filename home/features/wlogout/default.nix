{ config, pkgs, lib, ... }:

let
  palette = import ../theme/palette.nix;
  mocha = palette.mocha;
in
{
  programs.wlogout = {
    enable = true;
    layout = [
      {
        label = "lock";
        action = "hyprlock";
        text = "Lock";
        keybind = "l";
      }
      {
        label = "logout";
        action = "hyprctl dispatch exit";
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
        font-family: ${palette.fonts.mono};
      }

      window {
        background-color: ${palette.cssRgba mocha.base "0.85"};
      }

      button {
        color: ${mocha.text};
        background-color: ${palette.cssRgba mocha.surface0 "0.8"};
        border-style: solid;
        border-width: 2px;
        border-color: ${mocha.surface1};
        background-repeat: no-repeat;
        background-position: center;
        background-size: 25%;
        border-radius: ${palette.radius.xl};
        margin: 10px;
        transition: all 0.3s ease;
      }

      button:focus, button:active, button:hover {
        background-color: ${palette.cssRgba mocha.surface1 "0.9"};
        border-color: ${palette.accent};
        outline-style: none;
      }

      #lock {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/lock.png"));
      }

      #logout {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/logout.png"));
      }

      #suspend {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/suspend.png"));
      }

      #shutdown {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/shutdown.png"));
      }

      #reboot {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/reboot.png"));
      }
    '';
  };
}
