{ pkgs, toolchain, ... }:
let
  # Build the crate with the same pinned toolchain the dev shell uses.
  rustPlatform = pkgs.makeRustPlatform {
    cargo = toolchain;
    rustc = toolchain;
  };
in
rustPlatform.buildRustPackage {
  pname = "rust-template";
  version = "0.1.0";
  src = builtins.path { path = ./.; name = "source"; };
  cargoLock.lockFile = ./Cargo.lock;
}
