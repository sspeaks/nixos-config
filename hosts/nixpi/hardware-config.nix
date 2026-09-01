{ inputs, pkgs, lib, ... }: {
  imports = [
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
  ];
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };
  };
  swapDevices = [{ device = "/swapfile"; size = 4096; }];

  # Kernel 6.18+ added PREEMPT_LAZY as a 4th preemption-model choice. nixpkgs
  # common-config.nix enables it for >=6.18, colliding with nixos-hardware's
  # forced `PREEMPT = mkForce yes` (raspberry-pi/common/kernel.nix): two enabled
  # options in the same Kconfig `choice` make config generation crash with
  # "Error in reading or end of file". Upstream fix is tracked in
  # NixOS/nixos-hardware#1920 (add `PREEMPT_LAZY = mkForce no`); until it lands
  # we inject it ourselves.
  #
  # nixos-hardware's rpi4 kernel hardcodes both `kernelPatches` and
  # `structuredExtraConfig`, so plain `boot.kernelPatches` is silently dropped.
  # Re-derive its kernel and override the patch list through `argsOverride`
  # (the one arg the wrapper honours), re-listing the stock patches so they are
  # preserved, and add a config-only patch that forces PREEMPT_LAZY off.
  boot.kernelPackages = pkgs.linuxPackagesFor (
    (pkgs.callPackage "${inputs.nixos-hardware}/raspberry-pi/common/kernel.nix" {
      rpiVersion = 4;
    }).override {
      argsOverride.kernelPatches = (with pkgs.kernelPatches; [
        bridge_stp_helper
        request_key_helper
      ]) ++ [{
        name = "disable-preempt-lazy";
        patch = null;
        structuredExtraConfig.PREEMPT_LAZY = lib.mkForce lib.kernel.no;
      }];
    }
  );
}
