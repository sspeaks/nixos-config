# Work Routing

How to decide who handles what.

## Routing Table

| Work Type | Route To | Examples |
|-----------|----------|----------|
| Design direction & cohesion | Morpheus | Set the look/mood, arbitrate taste, cross-app consistency, aesthetic review |
| Compositor & motion | Trinity | Hyprland/Wayland config, animations, layouts, blur/shadow/rounding, window rules, keybinds |
| Bars, widgets & menus | Switch | waybar/eww/ags, wofi/rofi launchers, dunst/mako notifications, wlogout/hyprlock styling |
| Color & theming | Mouse | Palette/colorscheme, semantic tokens, GTK/Qt/icon/cursor themes, contrast/legibility |
| Typography, terminal & Nix | Tank | Nerd fonts, ghostty/alacritty, starship prompt, wallpaper, home-manager/flake module structure |
| Aesthetic / design review | Morpheus | Judge whether work is cohesive and on-direction; approve/reject |
| Verification & devil's advocate | Fact Checker | Verify claims (packages/options exist), challenge design assumptions, pre-mortem |
| Scope & priorities | Morpheus | What to rice next, trade-offs, direction |
| Session logging | Scribe | Automatic — never needs routing |
| RAI review | Rai | Content safety, credential detection, ethical review |

## Issue Routing

| Label | Action | Who |
|-------|--------|-----|
| `squad` | Triage: analyze issue, assign `squad:{member}` label | Lead |
| `squad:{name}` | Pick up issue and complete the work | Named member |

### How Issue Assignment Works

1. When a GitHub issue gets the `squad` label, the **Lead** triages it — analyzing content, assigning the right `squad:{member}` label, and commenting with triage notes.
2. When a `squad:{member}` label is applied, that member picks up the issue in their next session.
3. Members can reassign by removing their label and adding another member's label.
4. The `squad` label is the "inbox" — untriaged issues waiting for Lead review.

## Rules

1. **Eager by default** — spawn all agents who could usefully start work, including anticipatory downstream work.
2. **Scribe always runs** after substantial work, always as `mode: "background"`. Never blocks.
3. **Quick facts → coordinator answers directly.** Don't spawn an agent for "what port does the server run on?"
4. **When two agents could handle it**, pick the one whose domain is the primary concern.
5. **"Team, ..." → fan-out.** Spawn all relevant agents in parallel as `mode: "background"`.
6. **Anticipate downstream work.** If a feature is being built, spawn the tester to write test cases from requirements simultaneously.
7. **Issue-labeled work** — when a `squad:{member}` label is applied to an issue, route to that member. The Lead handles all `squad` (base label) triage.
