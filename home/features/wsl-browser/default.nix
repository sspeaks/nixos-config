{ lib, pkgs, ... }:

let
  windowsBrowser = pkgs.writeShellScriptBin "windows-browser" ''
    set -eu

    powershell="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
    if [ ! -x "$powershell" ]; then
      echo "Windows PowerShell was not found at $powershell" >&2
      exit 1
    fi

    if [ "$#" -eq 0 ]; then
      echo "usage: windows-browser URL..." >&2
      exit 64
    fi

    for target in "$@"; do
      "$powershell" -NoProfile -NonInteractive -Command 'Start-Process -FilePath $args[0]' "$target"
    done
  '';
in
{
  home = {
    packages = [
      windowsBrowser
      pkgs.xdg-utils
    ];

    sessionVariables.BROWSER = "${windowsBrowser}/bin/windows-browser";
  };

  programs.zsh.sessionVariables.BROWSER = "${windowsBrowser}/bin/windows-browser";

  xdg.desktopEntries.windows-browser = {
    name = "Windows Default Browser";
    genericName = "Web Browser";
    exec = "${windowsBrowser}/bin/windows-browser %u";
    terminal = false;
    categories = [
      "Network"
      "WebBrowser"
    ];
    mimeType = [
      "text/html"
      "application/xhtml+xml"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
    ];
  };

  home.activation.setWindowsBrowserMimeDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for mime in \
      text/html \
      application/xhtml+xml \
      x-scheme-handler/http \
      x-scheme-handler/https
    do
      $DRY_RUN_CMD ${pkgs.xdg-utils}/bin/xdg-mime default windows-browser.desktop "$mime"
    done
  '';
}
