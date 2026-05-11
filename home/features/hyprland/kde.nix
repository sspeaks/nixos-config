{ ... }:

{
  xdg.configFile."menus/applications.menu".text = ''
    <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
      "http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">
    <Menu>
      <Name>Applications</Name>
      <DefaultAppDirs/>
      <DefaultDirectoryDirs/>
      <DefaultMergeDirs/>
      <Include>
        <All/>
      </Include>
    </Menu>
  '';

  xdg.configFile."kdeglobals".text = ''
    [ColorEffects:Disabled]
    Color=56,56,56
    ColorAmount=0
    ColorEffect=0
    ContrastAmount=0.65
    ContrastEffect=1
    IntensityAmount=0.1
    IntensityEffect=2

    [ColorEffects:Inactive]
    ChangeSelectionColor=true
    Color=112,111,110
    ColorAmount=0.025
    ColorEffect=2
    ContrastAmount=0.1
    ContrastEffect=2
    Enable=false
    IntensityAmount=0
    IntensityEffect=0

    [Colors:Button]
    BackgroundAlternate=30,87,116
    BackgroundNormal=41,44,48
    DecorationFocus=61,174,233
    DecorationHover=61,174,233
    ForegroundActive=61,174,233
    ForegroundInactive=161,169,177
    ForegroundLink=29,153,243
    ForegroundNegative=218,68,83
    ForegroundNeutral=246,116,0
    ForegroundNormal=252,252,252
    ForegroundPositive=39,174,96
    ForegroundVisited=155,89,182

    [Colors:Complementary]
    BackgroundAlternate=30,87,116
    BackgroundNormal=32,35,38
    DecorationFocus=61,174,233
    DecorationHover=61,174,233
    ForegroundActive=61,174,233
    ForegroundInactive=161,169,177
    ForegroundLink=29,153,243
    ForegroundNegative=218,68,83
    ForegroundNeutral=246,116,0
    ForegroundNormal=252,252,252
    ForegroundPositive=39,174,96
    ForegroundVisited=155,89,182

    [Colors:Header]
    BackgroundAlternate=32,35,38
    BackgroundNormal=41,44,48
    DecorationFocus=61,174,233
    DecorationHover=61,174,233
    ForegroundActive=61,174,233
    ForegroundInactive=161,169,177
    ForegroundLink=29,153,243
    ForegroundNegative=218,68,83
    ForegroundNeutral=246,116,0
    ForegroundNormal=252,252,252
    ForegroundPositive=39,174,96
    ForegroundVisited=155,89,182

    [Colors:Selection]
    BackgroundAlternate=30,87,116
    BackgroundNormal=61,174,233
    DecorationFocus=61,174,233
    DecorationHover=61,174,233
    ForegroundActive=252,252,252
    ForegroundInactive=161,169,177
    ForegroundLink=253,188,75
    ForegroundNegative=176,55,69
    ForegroundNeutral=198,92,0
    ForegroundNormal=252,252,252
    ForegroundPositive=23,104,57
    ForegroundVisited=155,89,182

    [Colors:Tooltip]
    BackgroundAlternate=32,35,38
    BackgroundNormal=41,44,48
    DecorationFocus=61,174,233
    DecorationHover=61,174,233
    ForegroundActive=61,174,233
    ForegroundInactive=161,169,177
    ForegroundLink=29,153,243
    ForegroundNegative=218,68,83
    ForegroundNeutral=246,116,0
    ForegroundNormal=252,252,252
    ForegroundPositive=39,174,96
    ForegroundVisited=155,89,182

    [Colors:View]
    BackgroundAlternate=29,31,34
    BackgroundNormal=20,22,24
    DecorationFocus=61,174,233
    DecorationHover=61,174,233
    ForegroundActive=61,174,233
    ForegroundInactive=161,169,177
    ForegroundLink=29,153,243
    ForegroundNegative=218,68,83
    ForegroundNeutral=246,116,0
    ForegroundNormal=252,252,252
    ForegroundPositive=39,174,96
    ForegroundVisited=155,89,182

    [Colors:Window]
    BackgroundAlternate=41,44,48
    BackgroundNormal=32,35,38
    DecorationFocus=61,174,233
    DecorationHover=61,174,233
    ForegroundActive=61,174,233
    ForegroundInactive=161,169,177
    ForegroundLink=29,153,243
    ForegroundNegative=218,68,83
    ForegroundNeutral=246,116,0
    ForegroundNormal=252,252,252
    ForegroundPositive=39,174,96
    ForegroundVisited=155,89,182

    [General]
    ColorScheme=BreezeDark
    Name=Breeze Dark
    shadeSortColumn=true

    [Icons]
    Theme=breeze-dark

    [KDE]
    LookAndFeelPackage=org.kde.breezedark.desktop
    contrast=4

    [WM]
    activeBackground=39,44,49
    activeBlend=252,252,252
    activeForeground=252,252,252
    inactiveBackground=32,36,40
    inactiveBlend=161,169,177
    inactiveForeground=161,169,177
  '';

  xdg.desktopEntries.dolphin = {
    name = "Dolphin";
    genericName = "File Manager";
    icon = "system-file-manager";
    exec = "dolphin %u";
    categories = [ "Qt" "KDE" "System" "FileTools" "FileManager" ];
    mimeType = [ "inode/directory" ];
  };

  home.file.".local/share/applications/imv.desktop".text = ''
    [Desktop Entry]
    Name=imv
    GenericName=Image Viewer
    Exec=imv %F
    Terminal=false
    Type=Application
    Icon=multimedia-photo-viewer
    Categories=Graphics;2DGraphics;Viewer;
    MimeType=image/jpeg;image/png;image/gif;image/bmp;image/svg+xml;image/webp;image/tiff;image/avif;image/heif;image/jxl;
  '';

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory" = "dolphin.desktop";
      "image/jpeg" = "imv.desktop";
      "image/png" = "imv.desktop";
      "image/gif" = "imv.desktop";
      "image/bmp" = "imv.desktop";
      "image/svg+xml" = "imv.desktop";
      "image/webp" = "imv.desktop";
      "image/tiff" = "imv.desktop";
      "image/avif" = "imv.desktop";
      "image/heif" = "imv.desktop";
      "application/pdf" = "org.pwmt.zathura.desktop";
      "video/mp4" = "mpv.desktop";
      "video/x-matroska" = "mpv.desktop";
      "video/webm" = "mpv.desktop";
    };
  };
}
