{ pkgs, lib ? pkgs.lib }:

# Native Mermaid renderer (no browser); not in nixpkgs
pkgs.rustPlatform.buildRustPackage rec {
  pname = "mermaid-rs-renderer";
  version = "0.3.1";

  src = pkgs.fetchFromGitHub {
    owner = "1jehuang";
    repo = "mermaid-rs-renderer";
    rev = "v${version}";
    hash = "sha256-uekh1vJ19dAPP7+4PiqSlJizApZLpDhBWBoyN+fgS9s=";
  };

  cargoHash = "sha256-L++Z5Zjv5tJANvdL/sbm9V+OZjYP/6IjrhYfjQ8/Vf4=";

  nativeBuildInputs = [ pkgs.pkg-config ];
  # Fonts are found at runtime via fontdb; Linux PNG rendering still wants fontconfig
  buildInputs = lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.fontconfig pkgs.freetype ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ pkgs.libiconv ];
  doCheck = false;

  meta = {
    description = "Fast native Mermaid diagram renderer";
    homepage = "https://github.com/1jehuang/mermaid-rs-renderer";
    license = lib.licenses.mit;
    mainProgram = "mmdr";
    platforms = lib.platforms.unix;
  };
}
