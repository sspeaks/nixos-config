{ pkgs, lib ? pkgs.lib, openaikey ? "/dev/null", ... }:
#  
# Build Example without flakes
# nix build --impure --expr "let pkgs = import <nixpkgs> {};  in pkgs.callPackage ./packages/askGPT4/default.nix {openaikey = \"/Users/sspeaks/.openapikey\";}"
# Install example without flakes 
# nix-env -i -f ./packages/askGPT4/default.nix -E 'p: let pkgs = import <nixpkgs> {}; in p {inherit pkgs; openaikey = "/home/sspeaks/.openaiapikey";}'
let
  openai = pkgs.python312Packages.buildPythonPackage rec {
    pname = "openai";
    version = "1.83.0";
    format = "wheel";
    src = pkgs.python312Packages.fetchPypi {
      inherit pname version format;
      dist = "py3";
      python = "py3";
      sha256 = "d15ec58ba52537d4abc7b744890ecc4ab3cffb0fdaa8e5389830f6e1a2f7f128";
    };
    propagatedBuildInputs = with pkgs.python312Packages; [ typing-extensions pydantic httpx distro jiter sniffio tqdm ];
    pythonImportsCheck = [ "openai" ];
  };
  pythonP = pkgs.python312.withPackages (ps: [ openai ps.python-magic ]);
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

  meta = {
    description = "CLI wrapper for OpenAI's GPT API";
    license = lib.licenses.unfree;
    mainProgram = "aai";
    platforms = lib.platforms.unix;
  };
}
