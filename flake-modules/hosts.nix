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
    # Home services on the same Pi 4 as the `nixpi` travel-router alternative.
    nixpi4 = mkHost ../hosts/nixpi4 [ ];
    NixOS-WSL = mkHost ../hosts/nixosWSL [ ];
    NixOS-WSL-work = mkHost ../hosts/nixosWSL-work [ inputs.vscode-server.nixosModules.default ];
    nixos-azure = mkHost ../hosts/nixos-azure [
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
    # Home Hyper-V VM taking vid-stream's workload off Azure. Gen2/UEFI, so it
    # gets the same disko treatment as the Azure x86_64 hosts -- an Azure VM is
    # a Hyper-V VM, so the guest layout is identical.
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
