{ pkgs, lib ? pkgs.lib }:

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

  meta = {
    description = "Git auto-commit helper powered by GitHub Copilot";
    license = lib.licenses.unfree;
    mainProgram = "gac";
    platforms = lib.platforms.unix;
  };
}
