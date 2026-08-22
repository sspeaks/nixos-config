# Project Context

- **Owner:** Seth Speaks
- **Project:** nixos-config — a personal NixOS "ricing" (desktop aesthetic customization) setup built with flakes + home-manager. Wayland desktop centered on Hyprland. Current look is Catppuccin Mocha (blue accent) with waybar, wofi, dunst, wlogout, hyprlock, starship, ghostty/alacritty, JetBrainsMono Nerd Font. A central `home/features/theme/palette.nix` exposes the palette + CSS/rgba helpers as the single re-theming knob.
- **Stack:** Nix, NixOS, home-manager, flakes; Hyprland (Wayland compositor); GTK/Qt theming; waybar, wofi, dunst, wlogout, hyprlock; starship; ghostty, alacritty; Nerd Fonts.
- **Created:** 2026-08-07T18:23:40-07:00

## Team Ethos (applies to me and every member)

1. **No bias toward the existing config.** The current stack has no special standing. Evaluate every choice — colorscheme, compositor, bar, launcher — on merit against real alternatives. Propose bold replacements when they're better.
2. **Be particularly opinionated.** Take a clear, defensible design position. Strong opinions, loosely held: argue hard, then commit once the team decides.
3. **Cohesion over collection.** A rice is one designed system, not a bag of independent dotfiles.

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->

📌 Team update (2026-08-08T00:00:00Z): Design Review + batch 1 APPROVED — Plate XIV orchestrated by Morpheus
- Strict lockout discipline (two rejection cycles → targeted remediation by assigned agents) scales well for concurrent work. Clear scoping (D1–D18) prevents scope creep in reviews.
- Cross-agent conflicts resolved via principled arbitration (D8: systemd launch overrule; D12: import placement ruling). Document the decision principle, not just the verdict.
- Validation gates (D18) catch flake paths, not runtime behavior. Eyes-on testing post-merge required for font resolution, SDDM rendering, Quickshell crashes. Plan live validation phase explicitly.
- File ownership matrix (batch-1 file ownership section) prevents double-touching. Enforce single-author-per-file in architectural contracts — prevents silent race conditions in parallel work.
- Two-layer rationale (WHAT + WHY) in decisions enables later batches to understand deferral reasons (D8, D14, D17). Decision text is the source of truth for "why not do X in this batch?"

📌 Team update (2026-08-07T20:19:14Z): Plate XIV Batch 1 validation merged and consolidated — CONDITIONAL GO recorded by Scribe
- Live sign-off verified independently by Fact Checker; all empirical findings consistent with Morpheus inspection
- Single known gap: SDDM greeter visual render (requires reboot or explicit restart to confirm persistence)
- Batch 2 unblocked conditionally; gap resolution owned by Seth or explicit acceptance
- Decision consolidated into .squad/decisions.md with full evidence chain
📌 Team update (2026-08-08T11:02:14.979-07:00): Batch 3 Design Review complete. D31 (oak wallpaper APPROVED), D32 (5 system controls APPROVED), D33 (Hyprland fallback confirmed). All CLI contracts verified. Fact Checker final approval. Live niri validation pending. — decided by Morpheus, Tank, Trinity, Mouse, Fact Checker

📌 Team update (2026-08-08T15:58:16.477-07:00): Sparse oak wallpaper direction was replaced by the deterministic Old-Growth Survey conifer forest. Morpheus reviewed the built wallpaper and APPROVED it. System controls also received final Fact Checker approval; both await live hardware/session validation only. — decided by Morpheus, Fact Checker
