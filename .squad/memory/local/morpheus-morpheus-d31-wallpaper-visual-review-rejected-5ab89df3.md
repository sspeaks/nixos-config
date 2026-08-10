---
id: 5ab89df3-c324-4a21-bd87-f5df3552c913
class: LOCAL
loadGuidance: [ON-DEMAND]
title: "Morpheus D31 wallpaper visual review — REJECTED"
author: "Morpheus"
createdAt: 2026-08-08T18:24:28.381Z
metadata: {}
---

## Morpheus Visual Review: D31 Oak-Branch Wallpaper (2026-08-08)

**Verdict: REJECTED**

### What works
- Grid substrate (void + 40px/160px hairline/rule) is intact and correct.
- Vermilion registration crosshair centered, visually isolated — good.
- Palette discipline is perfect: only line.rule and line.hairline used; no rogue colors.
- Negative space preserved: right half and upper portion entirely clear for desktop chrome.
- Branch arc trajectory (lower-left → upper-centre-left, ~38% canvas) matches D31 spec.

### What fails — the leaves do not read as oak

This is the critical defect. Every leaf is drawn as a narrow, pointed, symmetrical teardrop/lancet shape — they look like bay laurel or a generic willow, NOT Quercus robur. D31 explicitly calls for "deeply lobed margin" and "alternating shallow sinuses" characteristic of English oak. The current leaves have:
- No lobes whatsoever — the outlines are smooth convex curves
- No sinuses — the margin never indents inward
- Aspect ratio ~3:1 (too narrow); oak leaves are ~2:1 with a wide, rounded, multi-lobed profile
- Symmetrical pointed tips; oak leaves have rounded lobe tips

This means the "nature" request is only half-met: there IS an organic overlay, but it reads as a generic botanical sketch, not recognizably oak. At 3024×1964 on a retina display the leaves are large enough (~120px) that the lobe structure should be visible and identifiable.

### Secondary issues
1. **Leaf clustering:** Leaves 4/5/6 overlap heavily around (620-660, 1340-1520) creating a dense knot. D31 spec says "generous negative space" — these three need spreading.
2. **Leaf orientation uniformity:** Most leaves point with midrib perfectly vertical relative to canvas, not rotated to align with the local branch tangent. This makes them look pinned to a herbarium sheet rather than growing from the branch. 
3. **Vein fan too tight:** Lateral veins are nearly parallel to midrib (~10-15° spread). D31 says "~30° from midrib" — current veins lack the characteristic fan pattern of oak venation.

### Revision assignment
**Revision owner: Mouse** (not Tank, per Reviewer Rejection Protocol — original author cannot own the revision).

### Exact implementable corrections for Mouse
1. **Rework all 15 leaf outlines** to show 4-5 rounded lobes per side separated by sinuses that indent 30-40% of leaf half-width. Reference: Quercus robur margin profile — undulating, not smooth. Each lobe tip should be rounded (use quadratic Bézier arcs), each sinus a gentle inward notch. Target aspect ratio ~2:1 (width:length ~60px:120px).
2. **Rotate each leaf** so its midrib aligns with the twig/branch tangent vector at the attachment point (±15°). Currently they all point roughly north; they should fan outward along the branch arc.
3. **Spread leaves 4/5/6** apart — increase arc-length spacing between them by ~80-100px so they don't overlap.
4. **Widen lateral vein angle** to 25-35° from midrib, fanning outward toward lobe tips, not running nearly parallel.
5. **Do not change:** branch path, grid, crosshair, palette tokens, file structure, or build pipeline.
