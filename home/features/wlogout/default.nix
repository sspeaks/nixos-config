{ config, pkgs, lib, ... }:

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
        label = "hibernate";
        action = "systemctl hibernate";
        text = "Hibernate";
        keybind = "h";
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
        font-family: "JetBrainsMono Nerd Font";
      }

      window {
        background-color: rgba(30, 30, 46, 0.9);
      }

      button {
        color: #cdd6f4;
        background-color: #313244;
        border-style: solid;
        border-width: 2px;
        border-color: #45475a;
        background-repeat: no-repeat;
        background-position: center;
        background-size: 25%;
        border-radius: 15px;
        margin: 10px;
      }

      button:focus, button:active, button:hover {
        background-color: #45475a;
        border-color: #89b4fa;
        outline-style: none;
      }

      #lock {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/lock.png"));
      }
      #lock:hover {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/lock-hover.png"));
      }

      #logout {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/logout.png"));
      }
      #logout:hover {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/logout-hover.png"));
      }

      #suspend {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/suspend.png"));
      }
      #suspend:hover {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/suspend-hover.png"));
      }

      #hibernate {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/hibernate.png"));
      }
      #hibernate:hover {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/hibernate-hover.png"));
      }

      #shutdown {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/shutdown.png"));
      }
      #shutdown:hover {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/shutdown-hover.png"));
      }

      #reboot {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/reboot.png"));
      }
      #reboot:hover {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/reboot-hover.png"));
      }
    '';
  };
}
