{ pkgs, openaikey ? "/dev/null", ... }:
#  
# Build Example without flakes
# nix build --impure --expr "let pkgs = import <nixpkgs> {};  in pkgs.callPackage ./packages/askGPT4/default.nix {openaikey = \"/Users/sspeaks/.openapikey\";}"
# Install example without flakes 
# nix-env -i -f ./packages/askGPT4/default.nix -E 'p: let pkgs = import <nixpkgs> {}; in p {inherit pkgs; openaikey = "/home/sspeaks/.openaiapikey";}'
let
  openai = pkgs.python311Packages.buildPythonPackage rec {
    pname = "openai";
    version = "1.16.2";
    format = "wheel";
    src = pkgs.python311Packages.fetchPypi {
      inherit pname version format;
      dist = "py3";
      python = "py3";
      sha256 = "46a435380921e42dae218d04d6dd0e89a30d7f3b9d8a778d5887f78003cf9354";
    };
    propagatedBuildInputs = with pkgs.python311Packages; [ typing-extensions pydantic httpx distro ];
    pythonImportsCheck = [ "openai" ];
  };
  pythonP = pkgs.python311.withPackages (ps: [ openai ps.python-magic ]);
in
pkgs.stdenv.mkDerivation rec {
  name = "askGPT4";
  buildInputs = [ pythonP pkgs.makeWrapper ];
  unpackPhase = "true";
  OPEN_AI_KEY_FILE = openaikey;
  installPhase = ''
    mkdir -p $out/bin
    cp ${./askGPT4.py} $out/bin/aai
    chmod +x $out/bin/aai
  '';
  postFixup = ''
    wrapProgram $out/bin/aai \
    --set OPEN_AI_KEY ${OPEN_AI_KEY_FILE}
  '';
}
