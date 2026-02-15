{ pkgs }:

pkgs.stdenv.mkDerivation {
  pname = "ralph";
  version = "1.0.0";

  src = ./ralph;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin

    cp ralph.sh $out/bin/ralph
    cp ralph-prd.sh $out/bin/ralph-prd
    chmod +x $out/bin/ralph $out/bin/ralph-prd

    wrapProgram $out/bin/ralph \
      --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.jq pkgs.curl ]}

    wrapProgram $out/bin/ralph-prd \
      --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.curl ]}
  '';
}
