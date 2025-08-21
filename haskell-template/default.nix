{ pkgs ? import <nixpkgs> { }, ... }:
let src = builtins.path { path = ./.; name = "source"; };
in
pkgs.haskellPackages.callCabal2nix "test" src { }

