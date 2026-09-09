# Plate XIV — Quickshell shell module
#
# Exposes the Plate XIV shell config via programs.quickshell.configs."plate-xiv".
# Theme.qml is generated from home/features/theme/plate.nix so that all QML files
# reference named tokens rather than raw hex values.
#
# Activation:
#   Manual preview:  quickshell -c plate-xiv
#   Niri permanent:  spawn-at-startup "quickshell" "-c" "plate-xiv"
#
# This module intentionally omits programs.quickshell.systemd.enable so the shell
# does not autostart on Hyprland or any other compositor.
#
# QML formatting: 4-space indentation, properties in declaration order.

{ lib, pkgs, ... }:

let
  plate = import ../theme/plate.nix;

  # Strip a trailing "px" suffix and return an integer.
  # plate.geometry values are CSS-style strings ("1px", "4px", …).
  # QML numeric properties must receive Nix integers — never raw "Npx" strings.
  stripPx = s: lib.toInt (builtins.replaceStrings [ "px" ] [ "" ] s);

  # ── Theme.qml ─────────────────────────────────────────────────────────────
  # Generated from plate.nix tokens; the only place hex strings appear in the
  # QML tree.  All other QML files import this singleton by name.
  themeQml = pkgs.writeText "Theme.qml" ''
    pragma Singleton
    import QtQuick

    // Plate XIV design-token bridge.
    // DO NOT edit by hand — regenerate via home/features/quickshell/default.nix.
    QtObject {
        // Background layers (darkest → lightest)
        readonly property color bgVoid:   "${plate.bg.void}"
        readonly property color bgBase:   "${plate.bg.plate}"
        readonly property color bgRaised: "${plate.bg.panel}"
        readonly property color bgFill:   "${plate.bg.inset}"

        // Foreground text hierarchy
        readonly property color fgPrimary:   "${plate.fg.primary}"
        readonly property color fgSecondary: "${plate.fg.secondary}"
        readonly property color fgMuted:     "${plate.fg.muted}"

        // Structural lines
        readonly property color lineHairline: "${plate.line.hairline}"
        readonly property color lineRule:     "${plate.line.rule}"
        readonly property color lineEdge:     "${plate.line.edge}"

        // Accent / state
        readonly property color accentPrimary: "${plate.accent.vermilion}"
        readonly property color accentOn:      "${plate.accent.on}"
        // D25/D26 — failure/error state, consumed by NotificationCard's
        // critical-urgency border. Reuses vermilion; no new hue (D1/D25).
        readonly property color stateFail:     "${plate.state.fail}"
        // D32 — active/focus state for control sliders + toggle fill.
        // Reuses state.focus (= vermilion); exposed as a distinct role name
        // so Switch's control code reads as semantic intent, not hex.
        readonly property color stateFocus:    "${plate.state.focus}"

        // Geometry — numeric (px-stripped).  All QML size bindings use these.
        // captionHeight is fixed by D9 (exclusive-zone contract: 28 logical px).
        readonly property int captionHeight: 28
        readonly property int border:        ${toString (stripPx plate.geometry.border)}
        readonly property int spacingSm:     ${toString (stripPx plate.geometry.gap)}
        readonly property int spacingLg:     ${toString (stripPx plate.geometry.gapOuter)}

        // Typography
        readonly property string fontMono: "${plate.type.mono}"
        readonly property string fontTerm: "${plate.type.terminal}"
        readonly property string fontUi:   "${plate.type.mono}"
    }
  '';

  # ── Config directory ───────────────────────────────────────────────────────
  # Merge generated Theme.qml with the versioned QML sources.
  # programs.quickshell.configs expects a path; a derivation output is a valid path.
  configDir = pkgs.symlinkJoin {
    name = "quickshell-plate-xiv";
    paths = [
      (pkgs.runCommand "plate-xiv-theme" { } ''
        mkdir -p "$out"
        cp ${themeQml} "$out/Theme.qml"
      '')
      ./plate-xiv
    ];
  };
in
{
  programs.quickshell = {
    enable = true;
    # Explicit null package keeps quickshell on the default nixpkgs pin.
    # systemd integration disabled — shell is dormant until manually invoked
    # or added to `niri spawn-at-startup`.
    configs."plate-xiv" = configDir;
  };
}
