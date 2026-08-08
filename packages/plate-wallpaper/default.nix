# Plate XIV — deterministic wallpaper package (R5 / D5)
#
# Produces $out/share/backgrounds/plate-xiv.png at 3024×1964 from a
# compile-time SVG rendered via resvg.  No network access, no runtime
# mutation; output is fixed by the Nix derivation hash.
#
# Color source: ../../home/features/theme/plate.nix (sole authority per D5).
# - bg.void        background fill
# - line.hairline  40 px minor grid, 0.5 px strokes
# - line.rule      160 px major grid, 1 px strokes
# - accent.vermilion  exact-centre registration crosshair, ±16 px arms, 1 px
# No cartouche, no text.  SVG <pattern> elements ensure uniform coverage.
{ pkgs, ... }:

let
  t = import ../../home/features/theme/plate.nix;

  width = 3024;
  height = 1964;

  # Exact canvas centre for the registration crosshair.
  cx = width / 2; # 1512
  cy = height / 2; # 982
  arm = 16; # ±16 px

  svgSource = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <svg xmlns="http://www.w3.org/2000/svg"
         width="${toString width}" height="${toString height}"
         viewBox="0 0 ${toString width} ${toString height}">

      <defs>
        <!-- 40 px minor grid tile — line.hairline @ 0.5 px -->
        <pattern id="minor" x="0" y="0" width="40" height="40"
                 patternUnits="userSpaceOnUse">
          <path d="M 40 0 L 0 0 0 40"
                fill="none"
                stroke="${t.line.hairline}"
                stroke-width="0.5"/>
        </pattern>

        <!-- 160 px major grid tile — line.rule @ 1 px -->
        <pattern id="major" x="0" y="0" width="160" height="160"
                 patternUnits="userSpaceOnUse">
          <path d="M 160 0 L 0 0 0 160"
                fill="none"
                stroke="${t.line.rule}"
                stroke-width="1"/>
        </pattern>
      </defs>

      <!-- void ground -->
      <rect width="${toString width}" height="${toString height}"
            fill="${t.bg.void}"/>

      <!-- minor grid — 40 px, hairline -->
      <rect width="${toString width}" height="${toString height}"
            fill="url(#minor)"/>

      <!-- major grid — 160 px, rule -->
      <rect width="${toString width}" height="${toString height}"
            fill="url(#major)"/>

      <!-- registration crosshair — exact centre, vermilion, ±16 px arms -->
      <line x1="${toString (cx - arm)}" y1="${toString cy}"
            x2="${toString (cx + arm)}" y2="${toString cy}"
            stroke="${t.accent.vermilion}" stroke-width="1"/>
      <line x1="${toString cx}" y1="${toString (cy - arm)}"
            x2="${toString cx}" y2="${toString (cy + arm)}"
            stroke="${t.accent.vermilion}" stroke-width="1"/>

    </svg>
  '';
in
pkgs.runCommandLocal "plate-wallpaper"
{
  nativeBuildInputs = [ pkgs.resvg ];
  src = pkgs.writeText "plate-xiv.svg" svgSource;
} ''
  mkdir -p $out/share/backgrounds
  resvg "$src" "$out/share/backgrounds/plate-xiv.png"
''
