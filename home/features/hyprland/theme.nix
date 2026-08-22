{ pkgs, ... }:

# D16: GTK/icons/cursor migrated to neutral Plate XIV packages (aarch64 verified).
# adw-gtk3 dark, Papirus-Dark, Bibata-Modern-Classic size 36.
{
  # hyprpaper crashes on Asahi Linux due to a null monitor description; swaybg is used instead.
  services.hyprpaper.enable = false;

  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };

  gtk.gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
  gtk.gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
  gtk.gtk4.theme = null;

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "adw-gtk3-dark";
  };

  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style.name = "adwaita-dark";
  };

  home.pointerCursor = {
    enable = true;
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 36;
    gtk.enable = true;
  };
}
