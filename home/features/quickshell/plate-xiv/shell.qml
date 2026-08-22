// Plate XIV — shell root
//
// Entry point loaded by `quickshell -c plate-xiv`.
// Creates one Caption bar per attached screen, plus the three global
// (single-instance, not per-screen) Batch 2 surfaces: Launcher,
// NotificationHost, ControlCenter — each toggled via its own IPC target
// (Launcher/ControlCenter) or driven passively by the notification
// D-Bus service (NotificationHost). None of them anchor to a specific
// screen; Quickshell falls back to its default/focused screen for
// unanchored PanelWindows, consistent with how Caption is the only
// surface that needs explicit per-screen placement.
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

    // Global surfaces — one instance each, not per-screen (D22/D23).
    Launcher {}

    // ControlCenter is declared first and given an id so NotificationHost
    // (below) can reactively reserve space below it — see the "Overlap
    // fix" note in NotificationHost.qml. QML resolves sibling id
    // references at binding-evaluation time, so declaration order here
    // does not matter functionally; ControlCenter first just reads
    // top-to-bottom in the order the binding depends on it.
    ControlCenter {
        id: controlCenter
    }

    NotificationHost {
        // Deterministically relocate below ControlCenter instead of
        // overlapping it whenever ControlCenter is open (review
        // follow-up), so notifications — critical ones included — are
        // never obscured.
        reserveTop: controlCenter.visible
            ? controlCenter.implicitHeight + Theme.spacingLg
            : 0
    }
}
