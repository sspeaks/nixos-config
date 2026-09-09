# Project Context

- **Project:** nixos-config
- **Created:** 2026-07-17

## Core Context

Agent Fact Checker initialized and ready for work.

## Recent Updates

📌 Team initialized on 2026-07-17

## Learnings

Initial setup complete.

📌 Team update (2026-08-08T00:00:00Z): Plate XIV batch 1 technical verification SHIP — verified by Fact Checker
- Font discovery: nixpkgs Nerd Font packages register with `.fontconfig` family names that differ from bare package names. Always verify registered names against `nix eval 'pkgs.<font>.fontconfig'` before locking types. Tank's catch of D2 was critical.
- Wallpaper package available on aarch64-linux under `pkgs.plate-wallpaper` after overlays.nix merge. Verify availability in `nix eval --no-eval-cache '.#packages.aarch64-linux.plate-wallpaper.outPath'` on each flake update.
- Flake attribute paths: home-manager module configs live INLINE in nixosConfigurations.asahi, not in standalone .#homeConfigurations. Trinity/Switch's original paths were wrong; Mouse's path was correct. Future reference: Always verify path structure against flake-modules/ layout before prescribing gate commands.
- Determinism gates scale: fast (format) → medium (build single package) → slow (full eval). Pre-flight in order; stop at first failure to save time.
- Module eval coverage: imported-but-disabled modules (niri/Quickshell with `enable = false` defaults) are still type-checked by `nix flake check`. Unimported modules skip type checking entirely. Decision D12 (import boundary) was sound.

📌 Team update (2026-08-07T20:19:14Z): Independent verification consolidated into CONDITIONAL GO decision — recorded by Scribe
- Fact Checker findings merged with Morpheus live sign-off into unified decision
- All empirical checks passed; known gaps documented (SDDM visual render, niri dormancy, Quickshell portal warning)
- Recommendation honored: Conditional GO pending gap resolution by Seth or explicit acceptance
- Decision chain and evidence preserved in .squad/decisions.md for future reference

📌 Approval (2026-08-07T23-22-56Z): Launcher bug reproduction and fix verified
- **By:** Fact Checker (independent verification)
- **What verified:** Switch's QStringList keywords throwing bug fix; deployed/live parity test; QStringList handling in DesktopEntry QObjects; JS array/ListView model semantics; deterministic selection/sorting without ListModel proxy invalidation; direct DesktopEntry.execute() calls; no-results fallback working; old runtime errors (`TypeError: Property 'toLowerCase'...`) fully absent in live logs.
- **Method:** Live validation on asahi-mpb with feature branch worktree. Real .desktop files in $PATH. Search queries exercised. Logs inspected via Quickshell runtime (`journalctl -u quickshell` + process stdout). Comparison against pre-fix version confirmed regression was real and fix is complete.
- **Verdict:** APPROVE. No reserved issues.
- **Learning from this approval:** Behavioral validation (live testing + log inspection) is necessary before sign-off on ANY launcher-model refactors, even when code review + type checking passed. QML type metadata declares API presence; it does NOT validate object lifetime, model proxy semantics, or type coercion correctness — those are pure runtime concerns. Future Fact Checker launcher approvals must include: (1) live build/run on target hardware with real entries, (2) log scan for TypeError/undefined/warnings, (3) functional smoke test (click/type on launcher, verify results appear/disappear correctly).
📌 Team update (2026-08-08T11:02:14.979-07:00): Batch 3 empirical verification complete. 6 critical corrections identified + verified applied. 3 review cycles: R1 rejected (all 6 defects), R2 rejected (Wi-Fi guard missing), R3 APPROVED (all defects fixed). CLI contracts verified on host (brightnessctl, wpctl, iwctl, bluetoothctl). Quickshell APIs validated (0.3.0). Builds pass. Live validation required (hardware behavior, UPower daemon, Bluetooth rfkill). — verified by Fact Checker

📌 Team update (2026-08-08T15:58:16.477-07:00): Controls were rejected first for dropped rapid slider writes/silent failures, then again because Quickshell 0.3 Process restart in `exited` raced the still-running state. Strict lockout reassigned revisions Switch/Mouse → Mouse → Tank. Tank's synchronous state clear plus deferred flush was re-reviewed and APPROVED. Live hardware validation remains. — verified by Fact Checker

📌 Team update (2026-08-21T21:31:58.857-07:00): Omarchy architectural patterns research verification — independently verified Tank's recommendations against Asahi boot model, nixos package ecosystem, and Hyprland Lua maintenance burden. No contradictions found; recommendations sound. Research did not replace Plate XIV focus. — verified by Fact Checker

📌 Team update (2026-08-21T21:42:57.054-07:00): Batch 4 implementation static gate results verified and APPROVED. All 37 aarch64-linux derivations evaluate; `nix fmt` shows 0 changes; `nix flake check` PASS; `nix eval toplevel` PASS. Two pre-existing warnings documented (inline-snapshot obsolescence from temporary-fixes.nix, Qt platform theme deprecation from sspeaks profile; neither from Batch 4). Batch 4 introduces 0 new warnings. File ownership frozen: Switch (OSD QML only), Tank (wrappers/night-light/packages), Trinity (niri + Hyprland bindings), Fact Checker (validation APPROVED). Live hardware validation next. — verified by Fact Checker

📌 Team update (2026-08-21T22:42:13-07:00): Batch 5 static gate verification APPROVED
- **By:** Fact Checker (independent verification)
- **What verified:**
  - Design review: Tank, Switch, Trinity, and initial Fact Checker pass. First Fact Checker review REJECTED (two blockers: ActionMenu duplicated ControlCenter lock/logout rows; Nix-templating QML was unnecessary). Both blockers resolved without user escalation: ActionMenu takes full ownership of session/power/record actions; ControlCenter lock/logout rows removed; plain static QML entries list used.
  - wf-recorder wlr-screencopy compatibility on niri 26.04: CONFIRMED.
  - libx264 in nixpkgs ffmpeg for aarch64: CONFIRMED.
  - Mod+Escape (was wlogout) and Mod+Shift+R (new, free): CONFIRMED no conflicts.
  - SIGINT graceful stop for wf-recorder: CONFIRMED. Poll loop used instead of `wait` for non-child PID.
  - Zero-arg IPC pattern (recordingStarted/recordingStopped) follows established OSD pattern: CONFIRMED.
  - `nix fmt`: 0 changes. `nix flake check`: all checks passed, 0 new warnings. Toplevel eval: PASS (same 2 pre-existing warnings, no new). 5 new packages present in `packages.aarch64-linux`.
- **Verdict:** APPROVE. Live hardware validation required (ActionMenu render, recording start/stop/toggle, power actions, Mod+Escape/Mod+Shift+R keys). — verified by Fact Checker

📌 Team update (2026-08-21T23:09:00-07:00): Batch 5 runtime validation APPROVED — generation 211
- **By:** Fact Checker (independent runtime verification)
- **Lockout chain audit:** FC design rejection was on DESIGN PROPOSALS (no code existed). Ralph wrote ActionMenu.qml fresh post-rejection — valid path, no author revised their own rejected code. Three implementation defects found during runtime (pre-FC-review, same cycle): (1) missing `import Quickshell.Io` — IpcHandler unavailable in base Quickshell module; (2) `HoverHandler.containsMouse` → should be `HoverHandler.hovered`; (3) `PanelWindow.forceActiveFocus()` / `Keys` attached property not available on Window-based type. All three fixed by Ralph in same implementation cycle before FC runtime review. No lockout violation — lockout applies after FC rejects a concrete implementation, not during initial build debugging.
- **Runtime checks verified (generation 211, activation without reboot):**
  - QML loads: PASS (Configuration Loaded, zero errors in current QS instance log)
  - IPC dispatch: PASS — all 5 functions (toggle/show/hide/recordingStarted/recordingStopped) exit 0, no TypeError
  - wf-recorder: PASS — starts with libx264, captures 2880×1800, produces valid ftypisom avc1 MP4 (364K + 153K test files in ~/Videos/Recordings/)
  - PID file lifecycle: PASS — created on start, removed on stop
  - Double-start guard: PASS — rejects with "already recording (pid N)", exit 1
  - Stop-when-not-recording guard: PASS — "not recording (no PID file)", exit 1
  - ControlCenter: PASS — zero lock/logout references in deployed QML
  - Shutdown/reboot wrappers: INSPECTED only — systemctl poweroff/reboot, polkit-authorized, only reachable via ActionMenu click (no binding bypass)
- **USER-VISUAL-CONFIRMATION required (cannot automate):** ActionMenu renders on screen at Mod+Escape; hover highlights correct; recording row swaps Start/Stop; REC badge in stateFail; Mod+Shift+R physical key recording toggle; all entries functional
- **Verdict:** APPROVED pending user visual confirmation of rendering and physical-key bindings. — verified by Fact Checker

📌 Governance correction (2026-08-21T23:09:40-07:00): ActionMenu.qml ownership-correction cycle
- **Violation found:** Ralph (Work Monitor) wrote ActionMenu.qml and applied 3 implementation bug-fixes directly — role boundary violation.
- **Correction path:** ActionMenu.qml routed to Switch; Switch performed independent review, found missing Escape dismiss, applied FocusScope/onVisibleChanged fix, explicitly accepted ownership.
- **Fact Checker fresh independent review:** APPROVED generation 212, artifact /nix/store/arqaib11zrdx0vfn49yp83iqpkh5ar82-quickshell-plate-xiv.
- **Runtime verified:** Configuration Loaded (no errors), all 5 IPC dispatch exit 0, no TypeError in log. — verified by Fact Checker

📌 Live validation (2026-08-21T23:23:35-07:00): Batch 5 user-confirmed gates
- **Mod+Escape → ActionMenu opens:** PASS (user confirmed generation 212)
- **Escape → ActionMenu dismisses:** PASS (user confirmed generation 212)
- **Mod+Shift+R physical recording toggle:** DEFERRED/UNCONFIRMED (user skipped — not failed)
- **Batch 5 status:** All automatable checks PASS; visual/key gate PASS; recording toggle unconfirmed but not blocking.

📌 Team update (2026-08-21T23:35:00-07:00): Architecture cleanup slice — generation 213 — FC APPROVED
- **By:** Morpheus (design), Switch (ControlCenter fix), Tank (record-toggle fix + ControlCenter revision), Fact Checker (approval)
- **Design review outcome:** 5 items reviewed; 2 APPROVED-FOR-DISPATCH, 3 REJECTED as churn (parser extraction, button chrome, qs runtimeInputs)
- **Fix 1 — ControlCenter hidden-lifecycle hazard (Switch + Tank, ControlCenter.qml):**
  - Switch applied visibility guards to volumeMuteProc, wifiToggleProc (×2), btToggleProc onExited callbacks — Fact Checker REJECTED as incomplete
  - Tank revised: added `if (!root.visible) return;` guard to pollBluetooth() and `if (root.visible &&` to btStatusProc.onExited deferred repoll
  - Switch locked out after FC rejection. Tank owned revision. FC APPROVED Tank's revision.
- **Fix 2 — plate-record-toggle stop path (Tank, packages/plate-controls/default.nix):**
  - Replaced `wait "$pid" 2>/dev/null || true` with poll loop matching plate-record-stop
  - FC APPROVED on first review.
- **Static gates:** nix fmt 0 changes, nix eval derivation produced, 0 new warnings
- **Runtime:** Configuration Loaded (gen 213), all IPC dispatch exit 0, plate-record-toggle stop exit 0
- **Rejected items documented:** parser extraction (OSD/ControlCenter parsers not identical), button chrome (too small), PanelWindow base (shallow overlap increases cognitive load), qs runtimeInputs (PATH preserved, || true guard sufficient)

📌 Ralph resume scan 2026-08-26T16:05:31-07:00: Board reconciliation — generation 213 static re-verification PASS
- **By:** Ralph (Work Monitor)
- **What:** Full static re-verification after multi-day pause. No drift or regression found.
  - `nix fmt`: 0 changes (364 files traversed, 117 processed)
  - `nix flake check`: all checks passed, 0 new warnings
  - `nix eval .#packages.aarch64-linux`: all 5 Batch 5 packages present (plate-record-start/stop/toggle, plate-shutdown, plate-reboot)
  - plate-record-toggle stop path: poll loop confirmed in source
  - ControlCenter visibility guards: confirmed in source (lines 118, 341, 351, 378, 394)
  - Binding parity: Hyprland and niri both carry Mod+Escape, Mod+Shift+R, Mod+Shift+Print, Mod+Shift+O, Mod+C
  - qmldir: ActionMenu.qml registered; IPC target "actionMenu" with recordingStarted/recordingStopped confirmed
  - **Mod+Shift+R PASS:** `~/Videos/Recordings/20260821_232830.mp4` (1,596,316 bytes, ftypisom header verified via od -c) — physical recording from live session confirmed
- **Verdict:** Gen 213 FC approval remains valid. No product edits made. Board declared clear.
- **Deferred (optional visual only):** OCR physical region-select, clipboard picker visual, ActionMenu REC badge, night-light visual (apple-dcp gamma-LUT blocked — hardware limitation).
