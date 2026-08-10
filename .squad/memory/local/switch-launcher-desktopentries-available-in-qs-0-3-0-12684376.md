---
id: 12684376-f506-4716-8722-4e31dc991b82
class: LOCAL
loadGuidance: [ON-DEMAND]
title: "Launcher: DesktopEntries available in QS 0.3.0"
author: "Switch"
createdAt: 2026-08-08T05:52:00.740Z
metadata: {}
---

DesktopEntries singleton IS available in Quickshell 0.3.0 (Quickshell/DesktopEntries 0.0, confirmed via quickshell-core.qmltypes). .applications.values → QObjectList of DesktopEntry (.name, .genericName, .keywords, .noDisplay, .id, .execute()). The prior Launcher.qml comment claiming DesktopEntries was absent was incorrect. Launcher.qml now uses it for real XDG app search. Decision: app-first launcher with raw-cmd fallback. Plate XIV accentPrimary=vermilion is the selection token; accentOn=white for text on selection.
