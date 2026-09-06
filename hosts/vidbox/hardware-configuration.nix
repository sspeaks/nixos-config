{ lib, ... }:
# Hardware for `vidbox`: a Gen2 (UEFI) Hyper-V guest on the Windows desktop.
#
# Deliberately NOT importing nixpkgs' azure-common.nix, which is what
# hosts/nixos-azure/hardware-configuration.nix pulls in. That module exists to
# integrate with the Azure fabric -- waagent provisioning, and taking the
# hostname from Azure rather than from configuration -- none of which applies to
# a VM on a desktop in the house. The two platforms share a hypervisor, not a
# control plane.
#
# Hyper-V guest support needs no explicit configuration ONCE USERSPACE IS UP:
# the hv_* drivers ship with the standard NixOS kernel and bind automatically.
# That is exactly what makes the next block easy to get wrong -- see below.
#
# Hyper-V guest drivers must also be in the INITRD, not merely available to the
# booted system, and getting that wrong is fatal. The first install of this host
# failed at boot with
#
#   Timed out waiting for device /dev/disk/by-partlabel/disk-main-root
#
# because without hv_storvsc the synthetic SCSI controller never appears, so the
# root partition does not exist as far as the initrd is concerned. The booted
# system would have been fine -- it just could never get there.
#
# nixos-generate-config would normally detect these. This file was written by
# hand, so they are set explicitly, matching nixpkgs' azure-common.nix, which is
# precisely why hosts/nixos-azure boots on the same hypervisor.
{
  boot.initrd.kernelModules = [
    "hv_vmbus"
    "hv_storvsc"
    "hv_utils"
    "hv_netvsc"
  ];

  # Filesystems come from ./disko.nix, which is injected via
  # flake-modules/hosts.nix rather than imported here.

  # A file rather than a partition, so the disko layout stays a simple two
  # partition GPT and the size can change without repartitioning. Sized to match
  # the Azure host it replaces.
  swapDevices = [{ device = "/swapfile"; size = 8192; }];

  networking = {
    # Static, unlike nixos-azure which deliberately leaves this empty to inherit
    # the name from the Azure fabric. Nothing hands this VM a name.
    hostName = "vidbox";
    useDHCP = lib.mkDefault true;
    enableIPv6 = false;
  };

  nixpkgs.hostPlatform = "x86_64-linux";
}
