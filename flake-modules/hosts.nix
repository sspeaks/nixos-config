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
    # Same Pi 4 as `nixpi`, minus the travel-router stack.
    nixpi4-bare = mkHost ../hosts/nixpi4-bare [ ];
    NixOS-WSL = mkHost ../hosts/nixosWSL [ ];
    NixOS-WSL-work = mkHost ../hosts/nixosWSL-work [ inputs.vscode-server.nixosModules.default ];
    proxy = mkHost ../hosts/proxy [
      inputs.nixpkgs.nixosModules.notDetected
      "${inputs.nixpkgs}/nixos/modules/virtualisation/azure-image.nix"
    ];
    # The network hostname remains raspberrypi for Time Machine continuity.
    # sd-image-aarch64 adds the bootable SD artifact alongside the system closure.
    raspberrytimemachine = mkHost ../hosts/raspberrytimemachine [
      "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
    ];
    vm = mkHost ../hosts/vm [ ];
    # Disko supplies the Gen2/UEFI disk layout for this Hyper-V guest.
    vidbox = mkHost ../hosts/vidbox [
      inputs.disko.nixosModules.disko
      ../hosts/vidbox/disko.nix
    ];
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
