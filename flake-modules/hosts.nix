{ inputs, self, ... }:
let
  temporaryFixes = import ../temporary-fixes.nix;
  temporaryHostModules = temporaryFixes.hostModules or { };
  mkHost = path: extraModules: inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit inputs; outputs = self; };
    modules = [ path ] ++ extraModules;
  };
in
{
  flake.nixosConfigurations = {
    nixpi = mkHost ../hosts/nixpi [ ];
    NixOS-WSL = mkHost ../hosts/nixosWSL [ ];
    NixOS-WSL-work = mkHost ../hosts/nixosWSL-work [ ];
    nixos-azure = mkHost ../hosts/nixos-azure [
      inputs.disko.nixosModules.disko
      ../hosts/nixos-azure/disko.nix
    ];
    vid-stream = mkHost ../hosts/vid-stream [
      inputs.disko.nixosModules.disko
      ../hosts/nixos-azure/disko.nix
    ];
    pogbot = mkHost ../hosts/pogbot [ ];
    vm = mkHost ../hosts/vm [ ];
    asahi = mkHost ../hosts/asahi
      (inputs.nixpkgs.lib.optional (temporaryHostModules ? asahi) temporaryHostModules.asahi);
    nixpi5 = inputs.nixos-raspberrypi.lib.nixosSystem {
      specialArgs = { inherit inputs; outputs = self; nixos-raspberrypi = inputs.nixos-raspberrypi; };
      modules = [
        ../hosts/nixpi5
        inputs.nixos-raspberrypi.nixosModules.raspberry-pi-5.base
      ];
    };
  };
}
