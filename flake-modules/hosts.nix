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
    nixos-azure = mkHost ../hosts/nixos-azure [
      inputs.disko.nixosModules.disko
      ../hosts/nixos-azure/disko.nix
    ];
    vid-stream = mkHost ../hosts/vid-stream [
      inputs.disko.nixosModules.disko
      ../hosts/nixos-azure/disko.nix
    ];
    pogbot = mkHost ../hosts/pogbot [ ];
    # P2.1 replacement Azure edge: aarch64, Gen2 UEFI, specialized VHD.
    proxy = mkHost ../hosts/proxy [
      inputs.nixpkgs.nixosModules.notDetected
      "${inputs.nixpkgs}/nixos/modules/virtualisation/azure-image.nix"
    ];
    # P2.2 `.106` Time Machine appliance. Note the attribute name differs from
    # the host's own networking.hostName (`raspberrypi`) on purpose -- see the
    # continuity notes in hosts/raspberrytimemachine/default.nix.
    # sd-image-aarch64 is what provides config.system.build.sdImage; without it
    # there is no bootable SD artifact, only a toplevel closure.
    raspberrytimemachine = mkHost ../hosts/raspberrytimemachine [
      "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
    ];
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
