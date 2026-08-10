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
