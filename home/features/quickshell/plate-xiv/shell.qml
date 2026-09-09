// Entry point for `quickshell -c plate-xiv`, started by niri only.
// Caption is per-screen; other surfaces are single instances with no explicit
// screen assignment.
//
// Compositor requirements:
//   - wlr-layer-shell-unstable-v1     (PanelWindow)
//   - ext-workspace-v1                (WindowManager workspaces)
//   - wlr-foreign-toplevel-management (ToplevelManager window titles)
//

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: Caption {
            required property ShellScreen modelData
            screen: modelData
        }
    }

    // Global surfaces — one instance each, not per-screen.
    Launcher {}

    ControlCenter {
        id: controlCenter
    }

    NotificationHost {
        // Avoid overlap with ControlCenter without relying on layer stacking order.
        reserveTop: controlCenter.visible
            ? controlCenter.implicitHeight + Theme.spacingLg
            : 0
    }

    Osd {}

    ActionMenu {}
}
