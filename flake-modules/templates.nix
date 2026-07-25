{
  flake.templates = {
    haskell-template = {
      path = ../haskell-template;
      description = "Just a few files to help bootstrap a haskell project with nix";
    };
    rust-template = {
      path = ../rust-template;
      description = "Bootstrap a Rust project with a pinned rust-overlay toolchain + direnv dev shell";
    };
  };
}
