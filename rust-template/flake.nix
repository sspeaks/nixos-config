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
        # Single pinned toolchain (change `stable.latest` to a channel, a
        # version like `stable."1.85.0"`, or `nightly.latest`). `rust-src` and a
        # matched `rust-analyzer` are bundled so std completion works without
        # setting RUST_SRC_PATH.
        toolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" ];
          # Cross targets, e.g. to build x86_64 binaries (runnable here via the
          # host's binfmt emulation):
          # targets = [ "x86_64-unknown-linux-gnu" ];
        };
      in
      {
        packages.default = import ./default.nix { inherit pkgs toolchain; };
        devShells.default = import ./shell.nix { inherit pkgs toolchain; };
        formatter = pkgs.nixpkgs-fmt;
      });
}
