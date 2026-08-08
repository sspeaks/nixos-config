// Plate XIV — shell root
//
// Entry point loaded by `quickshell -c plate-xiv`.
// Creates one Caption bar per attached screen.
//
// Compositor requirements:
//   - wlr-layer-shell-unstable-v1     (PanelWindow)
//   - ext-workspace-v1                (WindowManager workspaces)
//   - wlr-foreign-toplevel-management (ToplevelManager window titles)
//
// Niri satisfies all three.  Hyprland satisfies all three but this shell is
// not spawned there — no spawn-at-startup entry exists in the Hyprland config.

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

ShellRoot {
    // One Caption surface per physical screen.
    Variants {
        model: Quickshell.screens

        delegate: Caption {
            required property ShellScreen modelData
            screen: modelData
        }
    }
}
