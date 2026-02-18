{ pkgs }:

pkgs.stdenv.mkDerivation {
  pname = "gac";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    cp gac.sh $out/bin/gac
    chmod +x $out/bin/gac
    wrapProgram $out/bin/gac \
      --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.git pkgs.myCopilot pkgs.gawk ]}
  '';
}
