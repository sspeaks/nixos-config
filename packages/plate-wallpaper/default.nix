# Plate XIV — deterministic wallpaper package (R5 / D5)
#
# Produces $out/share/backgrounds/plate-xiv.png at 3024×1964 from a
# compile-time SVG rendered via resvg. No network access or runtime mutation.
#
# Color source: ../../home/features/theme/plate.nix (sole authority per D5).
# - bg.void           ground and translucent mist
# - line.hairline     grid and distant forest
# - line.rule         midground/foreground engraving and silhouette washes
# - accent.vermilion  exact-centre registration crosshair only
#
# Art direction: “Plate XIV: Old-Growth Survey.” Three depth layers depict a
# Pacific Northwest conifer forest: distant trees behind a low ridge and mist,
# uneven midground Douglas-firs, and cropped hero trunks framing a fern-covered
# forest floor. The central-right mist clearing remains usable negative space.
{ pkgs, ... }:

let
  t = import ../../home/features/theme/plate.nix;

  width = 3024;
  height = 1964;
  cx = width / 2; # 1512
  cy = height / 2; # 982
  arm = 16; # ±16 px

  svgSource = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <svg xmlns="http://www.w3.org/2000/svg"
         width="${toString width}" height="${toString height}"
         viewBox="0 0 ${toString width} ${toString height}">
      <defs>
        <pattern id="minor" width="40" height="40" patternUnits="userSpaceOnUse">
          <path d="M40 0H0V40" fill="none" stroke="${t.line.hairline}"
                stroke-width="0.5"/>
        </pattern>
        <pattern id="major" width="160" height="160" patternUnits="userSpaceOnUse">
          <path d="M160 0H0V160" fill="none" stroke="${t.line.rule}"
                stroke-width="1"/>
        </pattern>

        <!-- Three deliberately different conifer profiles. -->
        <symbol id="fir-a" viewBox="0 0 200 1000">
          <path d="M100 8 L82 115 48 188 72 196 34 282 63 286 18 390
                   55 390 8 510 49 505 0 642 45 632 10 760 58 744
                   27 864 76 844 68 954 132 954 124 844 173 864
                   142 744 190 760 155 632 200 642 151 505 192 510
                   145 390 182 390 137 286 166 282 128 196 152 188
                   118 115Z"/>
          <path d="M100 78V970"/>
          <path d="M39 505Q100 480 161 505 M22 642Q100 610 178 642"/>
          <path d="M24 760Q100 720 176 760 M48 864Q100 830 152 864"/>
        </symbol>
        <symbol id="fir-b" viewBox="0 0 200 1000">
          <path d="M103 5 L73 151 91 148 47 240 72 235 28 333 60 326
                   10 438 55 425 3 553 47 540 17 654 64 632 22 754
                   72 730 39 842 80 818 70 956 130 956 121 818
                   166 842 133 730 181 754 139 632 184 654 154 540
                   198 553 148 425 190 438 142 326 174 333 130 235
                   153 240 113 148 132 151Z"/>
          <path d="M103 82L100 970"/>
          <path d="M31 438Q99 402 174 431 M21 553Q102 520 184 548"/>
          <path d="M34 654Q104 620 168 646 M45 754Q105 720 164 742"/>
        </symbol>
        <symbol id="fir-c" viewBox="0 0 200 1000">
          <path d="M98 7 L86 104 58 166 79 166 43 247 69 244 30 334
                   60 329 20 420 54 413 7 520 51 511 16 616 60 602
                   6 724 54 709 22 810 65 793 42 884 79 867 71 956
                   129 956 121 867 158 884 135 793 178 810 146 709
                   194 724 140 602 184 616 149 511 193 520 146 413
                   180 420 140 329 170 334 131 244 157 247 121 166
                   142 166 114 104Z"/>
          <path d="M98 72L101 970"/>
          <path d="M36 334Q99 310 164 332 M28 520Q101 487 178 514"/>
          <path d="M27 724Q99 686 173 715 M49 884Q101 850 151 879"/>
        </symbol>

        <symbol id="fern" viewBox="0 0 180 150">
          <path d="M10 140Q72 98 164 14"/>
          <path d="M45 111Q27 78 17 74 M60 96Q45 58 32 50
                   M78 79Q66 39 54 30 M99 61Q91 29 80 17"/>
          <path d="M48 108Q80 111 94 101 M65 92Q103 94 119 79
                   M84 75Q121 75 139 57 M105 56Q138 54 154 35"/>
        </symbol>
        <symbol id="rock" viewBox="0 0 180 100">
          <path d="M8 88Q19 47 58 42Q78 9 119 30Q155 31 174 88Z"/>
          <path d="M31 69L61 45 84 74 M111 33L131 67 158 71"/>
        </symbol>
      </defs>

      <rect width="${toString width}" height="${toString height}"
            fill="${t.bg.void}"/>
      <rect width="${toString width}" height="${toString height}"
            fill="url(#minor)" opacity="0.38"/>
      <rect width="${toString width}" height="${toString height}"
            fill="url(#major)" opacity="0.42"/>

      <!-- Distance: 22 simplified trees behind a low ridge. -->
      <g fill="${t.line.hairline}" fill-opacity="0.16"
         stroke="${t.line.hairline}" stroke-width="1.2" opacity="0.40">
        <use href="#fir-c" x="-35" y="785" width="170" height="850"/>
        <use href="#fir-b" x="90" y="910" width="125" height="625"/>
        <use href="#fir-a" x="205" y="830" width="158" height="790"/>
        <use href="#fir-c" x="350" y="930" width="120" height="600"/>
        <use href="#fir-b" x="455" y="790" width="175" height="875"/>
        <use href="#fir-a" x="610" y="890" width="135" height="675"/>
        <use href="#fir-c" x="730" y="820" width="160" height="800"/>
        <use href="#fir-b" x="875" y="940" width="116" height="580"/>
        <use href="#fir-a" x="980" y="850" width="148" height="740"/>
        <use href="#fir-c" x="1115" y="925" width="122" height="610"/>
        <use href="#fir-b" x="1225" y="860" width="144" height="720"/>
        <use href="#fir-a" x="1360" y="955" width="112" height="560"/>
        <use href="#fir-c" x="1460" y="875" width="138" height="690"/>
        <use href="#fir-b" x="1590" y="920" width="124" height="620"/>
        <use href="#fir-a" x="1700" y="835" width="150" height="750"/>
        <use href="#fir-c" x="1840" y="950" width="112" height="560"/>
        <use href="#fir-b" x="1940" y="870" width="140" height="700"/>
        <use href="#fir-a" x="2070" y="930" width="118" height="590"/>
        <use href="#fir-c" x="2178" y="805" width="162" height="810"/>
        <use href="#fir-b" x="2325" y="900" width="130" height="650"/>
        <use href="#fir-a" x="2440" y="825" width="155" height="775"/>
        <use href="#fir-c" x="2580" y="890" width="136" height="680"/>
      </g>
      <path d="M0 1455Q270 1340 545 1420T1070 1378T1590 1418
               T2110 1360T2585 1400T3024 1325V1645H0Z"
            fill="${t.line.hairline}" fill-opacity="0.14"
            stroke="${t.line.hairline}" stroke-width="2" opacity="0.42"/>

      <!-- Broad atmospheric bands separate distance from the survey trees. -->
      <g fill="none" stroke="${t.bg.void}" stroke-linecap="round">
        <path d="M-120 1190C480 1000 850 1180 1310 1080
                 C1780 975 2240 1095 3140 870"
              stroke-width="250" opacity="0.78"/>
        <path d="M-100 1390C520 1200 980 1370 1480 1240
                 C2030 1100 2500 1285 3140 1060"
              stroke-width="190" opacity="0.70"/>
      </g>

      <!-- Midground: eleven complete conifers, uneven and overlapping. -->
      <g fill="${t.line.rule}" fill-opacity="0.16"
         stroke="${t.line.rule}" stroke-width="2.2"
         stroke-linejoin="round" opacity="0.92">
        <use href="#fir-b" x="330" y="760" width="190" height="950"/>
        <use href="#fir-c" x="485" y="1000" width="142" height="710"/>
        <use href="#fir-a" x="635" y="545" width="230" height="1150"/>
        <use href="#fir-b" x="835" y="900" width="168" height="840"/>
        <use href="#fir-c" x="1010" y="1080" width="130" height="650"/>
        <use href="#fir-a" x="1145" y="960" width="155" height="775"/>
        <use href="#fir-b" x="2250" y="1015" width="145" height="725"/>
        <use href="#fir-c" x="2390" y="815" width="185" height="925"/>
        <use href="#fir-a" x="2555" y="1045" width="135" height="675"/>
        <use href="#fir-b" x="2670" y="775" width="194" height="970"/>
        <use href="#fir-c" x="2840" y="975" width="150" height="750"/>
      </g>

      <!-- Mist preserves the central-right clearing and isolates the mark. -->
      <g fill="none" stroke="${t.bg.void}" stroke-linecap="round">
        <path d="M1190 650C1510 520 1840 620 2180 470
                 C2420 365 2570 420 2730 350"
              stroke-width="310" opacity="0.83"/>
        <path d="M1130 1015C1480 875 1860 1010 2240 825
                 C2440 730 2600 760 2760 690"
              stroke-width="300" opacity="0.88"/>
      </g>

      <!-- Forest floor, fallen nurse log, and three rock groups. -->
      <path d="M0 1690Q240 1645 480 1700T950 1680T1430 1715
               T1920 1668T2400 1710T3024 1660V1964H0Z"
            fill="${t.line.rule}" fill-opacity="0.11"
            stroke="${t.line.rule}" stroke-width="2"/>
      <path d="M0 1840Q420 1780 830 1835T1650 1812T2340 1845T3024 1790"
            fill="none" stroke="${t.line.hairline}" stroke-width="2"/>
      <g fill="${t.line.rule}" fill-opacity="0.14"
         stroke="${t.line.rule}" stroke-width="2">
        <use href="#rock" x="380" y="1735" width="190" height="106"/>
        <use href="#rock" x="1735" y="1800" width="145" height="82"/>
        <use href="#rock" x="2375" y="1718" width="225" height="125"/>
      </g>
      <g fill="${t.line.rule}" fill-opacity="0.12"
         stroke="${t.line.rule}" stroke-width="2">
        <path d="M720 1780Q1180 1685 1665 1748L1688 1842
                 Q1190 1786 738 1885Z"/>
        <path d="M738 1781Q720 1800 738 1885 M1665 1748Q1708 1785 1688 1842"/>
        <path d="M800 1800Q1160 1740 1595 1780 M850 1840Q1190 1790 1550 1818"/>
        <path d="M980 1744L944 1695 M1320 1716L1348 1668 M1515 1730L1550 1688"/>
      </g>

      <!-- Reusable fern fronds: 15 varied placements across the bottom 300px. -->
      <g fill="none" stroke="${t.line.rule}" stroke-width="2"
         stroke-linecap="round" stroke-linejoin="round">
        <use href="#fern" x="20" y="1745" width="175" height="146"/>
        <use href="#fern" x="165" y="1695" width="205" height="171"/>
        <use href="#fern" x="330" y="1810" width="150" height="125"/>
        <use href="#fern" x="520" y="1720" width="190" height="158"/>
        <use href="#fern" x="690" y="1810" width="165" height="138"/>
        <use href="#fern" x="890" y="1700" width="210" height="175"/>
        <use href="#fern" x="1090" y="1800" width="155" height="129"/>
        <use href="#fern" x="1270" y="1740" width="185" height="154"/>
        <use href="#fern" x="1510" y="1815" width="145" height="121"/>
        <use href="#fern" x="1690" y="1705" width="205" height="171"/>
        <use href="#fern" x="1900" y="1795" width="160" height="133"/>
        <use href="#fern" x="2080" y="1715" width="195" height="163"/>
        <use href="#fern" x="2290" y="1805" width="150" height="125"/>
        <use href="#fern" x="2500" y="1690" width="215" height="179"/>
        <use href="#fern" x="2730" y="1765" width="180" height="150"/>
      </g>

      <!-- Foreground hero trunks: hand-authored irregular Douglas-fir bark. -->
      <g stroke="${t.line.rule}" stroke-linejoin="round">
        <path d="M64 1964L82 1760 70 1510 105 1280 119 1010 160 790
                 205 570 274 365 350 170 410 0H530L490 180 444 370
                 411 590 388 815 371 1045 365 1280 382 1510
                 360 1765 366 1964Z"
              fill="${t.line.rule}" fill-opacity="0.20" stroke-width="3"/>
        <path d="M2760 1964L2775 1740 2758 1510 2790 1280 2804 1030
                 2840 780 2865 535 2892 290 2928 0H3024V1964Z"
              fill="${t.line.rule}" fill-opacity="0.18" stroke-width="3"/>
      </g>
      <g fill="none" stroke="${t.line.rule}" stroke-width="2"
         stroke-linecap="round" opacity="0.92">
        <path d="M132 1928Q185 1670 142 1450T218 990T286 520T445 36"/>
        <path d="M228 1950Q265 1710 218 1510T292 1090T338 690T470 18"/>
        <path d="M330 1918Q298 1700 334 1490T318 1080T378 590T505 22"/>
        <path d="M92 1680L250 1605 M110 1390L342 1300 M150 1110L360 1018"/>
        <path d="M205 820L401 740 M252 535L444 454 M320 280L488 218"/>
        <path d="M2792 1930Q2840 1680 2805 1450T2860 980T2912 520T2970 20"/>
        <path d="M2880 1950Q2900 1700 2862 1500T2920 1060T2960 610T3000 30"/>
        <path d="M2778 1660L2994 1575 M2790 1340L3010 1250"/>
        <path d="M2815 1020L3020 930 M2850 700L3024 625 M2882 390L3024 320"/>
      </g>
      <g fill="none" stroke="${t.line.hairline}" stroke-width="1.2" opacity="0.72">
        <path d="M116 1810L292 1730 M102 1560L345 1468 M133 1240L355 1150"/>
        <path d="M176 940L382 850 M230 650L421 575 M292 380L470 305"/>
        <path d="M2782 1815L3010 1725 M2775 1490L3018 1400 M2805 1165L3020 1072"/>
        <path d="M2835 845L3020 755 M2870 545L3024 468 M2905 245L3024 180"/>
      </g>

      <!-- Exact-centre registration crosshair; vermilion appears nowhere else. -->
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
  src = pkgs.writeText "plate-xiv-old-growth-survey.svg" svgSource;
} ''
  mkdir -p $out/share/backgrounds
  resvg "$src" "$out/share/backgrounds/plate-xiv.png"
''
