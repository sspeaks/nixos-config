{
  description = "Bootstrap a Rust project with a pinned rust-overlay toolchain";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { nixpkgs, flake-utils, rust-overlay, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ rust-overlay.overlays.default ];
        };
        # Matching rust-src and rust-analyzer enable standard-library completion.
        toolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" ];
          # Additional compilation targets; running them may require emulation.
          # targets = [ "x86_64-unknown-linux-gnu" ];
        };
      in
      {
        packages.default = import ./default.nix { inherit pkgs toolchain; };
        devShells.default = import ./shell.nix { inherit pkgs toolchain; };
        formatter = pkgs.nixpkgs-fmt;
      });
}
