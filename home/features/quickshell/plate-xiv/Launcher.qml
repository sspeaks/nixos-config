// Launcher — Plate XIV application launcher overlay
//
// D22: Quickshell-native launcher for the niri session, replacing wofi.
// wofi stays the Hyprland-session fallback (D22, no re-theme required).
//
// IPC contract (D10, reused per D22): target "launcher", function
// toggle(): void.  Client bind order:
//   qs ipc -c plate-xiv call launcher toggle
// (`-c` belongs to the `ipc` subcommand, not `call`).
//
// D9 layer-shell contract: layer Overlay, no anchors (floats, centred by
// the compositor), exclusiveZone 0, keyboardFocus OnDemand — the only
// Plate XIV surface that takes keyboard focus, and only while open.
//
// App model: DesktopEntries singleton (Quickshell/DesktopEntries 0.0,
// present in the 0.3.0 nixpkgs build — verified via quickshell-core.qmltypes).
// .applications.values → QObjectList of DesktopEntry; each has .name,
// .genericName, .keywords, .noDisplay, .id, .execute().
// Matching is case-insensitive across name + genericName + keywords.
// Selection resets to first result on every query change.
// Enter launches the highlighted entry; Escape closes; Up/Down navigate.
// Falls back to raw shell command when no app matches (raw-cmd workflow
// preserved from D22).

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    visible: false

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    exclusiveZone: 0
    implicitWidth: 480
    // Height grows to show up to maxVisible result rows + input row + padding.
    implicitHeight: {
        const base = Theme.captionHeight + Theme.spacingLg * 2;
        const q    = input.text.trim();
        if (q.length === 0) return base;
        const rows = filteredApps.length === 0
            ? 1                                        // "no matches" row
            : Math.min(filteredApps.length, maxVisible);
        return base + Theme.border + rows * Theme.captionHeight;
    }
    color: "transparent"

    // Maximum number of result rows shown before the list scrolls.
    readonly property int maxVisible: 6

    // Index of the keyboard-selected result row; -1 = nothing selected.
    property int selectionIndex: -1

    // ── App filtering ───────────────────────────────────────────────────────
    // JS array of DesktopEntry QObjects; used directly as ListView model.
    // Avoids ListModel role-name conflicts and proxy-invalidation on clear().
    property var filteredApps: []

    function rebuildResults(): void {
        const q = input.text.trim().toLowerCase();
        if (q.length === 0) {
            root.filteredApps = [];
            root.selectionIndex = -1;
            return;
        }
        const all = DesktopEntries.applications.values;
        const matched = [];
        for (let i = 0; i < all.length; i++) {
            const app = all[i];
            if (!app || app.noDisplay) continue;
            const nm = String(app.name        || "").toLowerCase();
            const gn = String(app.genericName || "").toLowerCase();
            const kw = String(app.keywords    || "").toLowerCase();
            if (nm.includes(q) || gn.includes(q) || kw.includes(q))
                matched.push(app);
        }
        // Sort: entries whose name starts with the query appear first.
        matched.sort((a, b) => {
            const an = String(a.name || "").toLowerCase();
            const bn = String(b.name || "").toLowerCase();
            const ap = an.startsWith(q);
            const bp = bn.startsWith(q);
            if (ap !== bp) return ap ? -1 : 1;
            return an.localeCompare(bn);
        });
        root.filteredApps = matched;
        root.selectionIndex = matched.length > 0 ? 0 : -1;
    }

    // ── Launch helper ───────────────────────────────────────────────────────
    function launchSelected(): void {
        if (root.selectionIndex < 0 || root.selectionIndex >= root.filteredApps.length)
            return;
        root.filteredApps[root.selectionIndex].execute();
        root.visible = false;
    }

    // ── D10/D22 IPC contract ────────────────────────────────────────────────
    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.visible = !root.visible;
        }
    }

    // Reset on every open — never leak stale state from prior invocation.
    onVisibleChanged: {
        if (root.visible) {
            input.text = "";
            root.filteredApps = [];
            root.selectionIndex = -1;
            input.forceActiveFocus();
        }
    }

    // ── Visual shell ────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color:        Theme.bgRaised
        border.width: Theme.border
        border.color: Theme.lineEdge

        Column {
            id: contentCol
            anchors {
                top:    parent.top
                left:   parent.left
                right:  parent.right
                margins: Theme.spacingLg
            }

            // Input row
            RowLayout {
                width:  contentCol.width
                height: Theme.captionHeight
                spacing: Theme.spacingSm

                Text {
                    text:           ">"
                    font.family:    Theme.fontMono
                    font.pointSize: 11
                    color:          Theme.accentPrimary
                }

                TextInput {
                    id: input
                    Layout.fillWidth: true
                    font.family:      Theme.fontMono
                    font.pointSize:   11
                    color:            Theme.fgPrimary
                    selectByMouse:    true
                    focus:            true

                    onTextChanged: root.rebuildResults()

                    Keys.onEscapePressed: root.visible = false

                    Keys.onReturnPressed: {
                        if (root.selectionIndex >= 0) {
                            root.launchSelected();
                        } else {
                            // Raw-command fallback (no app match).
                            const cmd = input.text.trim();
                            if (cmd.length > 0)
                                Quickshell.execDetached(["sh", "-c", cmd]);
                            root.visible = false;
                        }
                    }

                    Keys.onUpPressed: {
                        if (filteredApps.length > 0) {
                            root.selectionIndex = Math.max(0, root.selectionIndex - 1);
                            resultsList.positionViewAtIndex(root.selectionIndex, ListView.Contain);
                        }
                    }

                    Keys.onDownPressed: {
                        if (filteredApps.length > 0) {
                            root.selectionIndex = Math.min(
                                filteredApps.length - 1, root.selectionIndex + 1);
                            resultsList.positionViewAtIndex(root.selectionIndex, ListView.Contain);
                        }
                    }
                }
            }

            // Divider — only visible when a query is active
            Rectangle {
                width:   contentCol.width
                height:  Theme.border
                color:   Theme.lineEdge
                visible: input.text.trim().length > 0
            }

            // "No matches" row
            Text {
                width:             contentCol.width
                height:            Theme.captionHeight
                visible:           input.text.trim().length > 0 && filteredApps.length === 0
                text:              "no matches"
                font.family:       Theme.fontMono
                font.pointSize:    11
                color:             Theme.fgMuted
                verticalAlignment: Text.AlignVCenter
                leftPadding:       Theme.spacingSm
            }

            // Results list — scrollable, capped at maxVisible rows
            ListView {
                id:      resultsList
                width:   contentCol.width
                height:  Math.min(filteredApps.length, root.maxVisible) * Theme.captionHeight
                visible: filteredApps.length > 0
                model:   filteredApps
                clip:    true

                delegate: Rectangle {
                    id: rowRect
                    required property var modelData   // DesktopEntry QObject
                    required property int index

                    width:  resultsList.width
                    height: Theme.captionHeight
                    // Vermilion fill on the selected row; inset fill otherwise.
                    color: root.selectionIndex === rowRect.index
                        ? Theme.accentPrimary
                        : Theme.bgFill

                    Text {
                        anchors {
                            verticalCenter: parent.verticalCenter
                            left:           parent.left
                            leftMargin:     Theme.spacingSm
                            right:          parent.right
                            rightMargin:    Theme.spacingSm
                        }
                        text:           rowRect.modelData.name
                        font.family:    Theme.fontMono
                        font.pointSize: 11
                        // White on vermilion; primary-fg on fill.
                        color: root.selectionIndex === rowRect.index
                            ? Theme.accentOn
                            : Theme.fgPrimary
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        // Hover moves the keyboard cursor — pointer stays consistent.
                        onEntered:  root.selectionIndex = rowRect.index
                        onClicked:  {
                            root.selectionIndex = rowRect.index;
                            root.launchSelected();
                        }
                    }
                }
            }
        }
    }
}
