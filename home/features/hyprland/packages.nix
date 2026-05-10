{ pkgs, ... }:

{
  home.packages = with pkgs; [
    grim
    slurp
    swappy

    wl-clipboard
    cliphist

    swaybg

    brightnessctl
    playerctl
    pavucontrol
    blueman

    hyprpicker

    lxqt.lxqt-policykit

    nautilus
    kdePackages.breeze-icons

    (pkgs.writeShellScriptBin "dolphin" ''
      exec env QT_QPA_PLATFORMTHEME=kde QT_STYLE_OVERRIDE=breeze-dark ${pkgs.kdePackages.dolphin}/bin/dolphin "$@"
    '')
    kdePackages.kio-extras
    kdePackages.kdegraphics-thumbnailers

    zathura
    imv
    mpv
  ];
}
