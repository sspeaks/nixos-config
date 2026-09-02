{ inputs, lib, outputs, ... }:
# P2.2 — `.106` converted from Debian to NixOS, still serving Time Machine.
#
# THE CRITICAL CONSTRAINT: never format, partition, or otherwise write to the
# USB disk holding the existing 593 GB of Time Machine backups. Only the SD
# card is reimaged. The USB disk is mounted BY UUID with no format action, and
# the Pi must still boot to a usable SSH login if that disk is absent.
#
# TWO CONTINUITY DECISIONS, both of which exist so macOS does not decide this
# is a NEW destination and start a 593 GB full backup from scratch:
#
#   1. networking.hostName stays `raspberrypi`, NOT `raspberrytimemachine`.
#      macOS identifies a Time Machine destination partly by the server's
#      advertised name. The flake attribute is `raspberrytimemachine` because
#      the migration plan names it that; the host's name on the network is
#      deliberately unchanged. Do not "fix" this to match.
#   2. The share stays `[backups]` and the `timemachine` user keeps uid/gid
#      1001, matching the Debian install exactly. The existing sparsebundle is
#      owned by uid 1001; any other uid makes it unwritable.
#
# Measured on the live Debian host 2026-09-02: sda2 ext4
# UUID 0adbb212-cb0d-4371-b452-940540914211, 916 GB total, 593 GB used by
# "Seth's MacBook Pro.sparsebundle", 277 GB free.
{
  imports = [
    ../common/global
    ../common/users/sspeaks
    ../common/users/sspeaks/authorized-keys.nix
    # Shared with `nixpi`: same Pi 4 hardware and the rpi4 kernel workaround.
    ../nixpi/hardware-config.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  nixpkgs.hostPlatform = "aarch64-linux";
  nixpkgs = {
    overlays = lib.mkDefault outputs.lib.overlayList;
    config.allowUnfree = lib.mkDefault true;
  };

  # sd-image-aarch64.nix imports profiles/base.nix, which turns on ZFS support.
  # That drags the ZFS kernel modules into the image and they fail to build
  # against the Raspberry Pi 6.18 kernel, taking `modules-shrunk` and therefore
  # the whole SD image down with them.
  #
  # This appliance has one ext4 USB disk and an ext4 SD card. ZFS is not merely
  # unnecessary here, it is the direct cause of the build failure.
  boot.supportedFilesystems.zfs = lib.mkForce false;

  networking = {
    hostName = "raspberrypi"; # continuity decision 1 -- see header
    useDHCP = lib.mkDefault true;
  };

  # ------------------------------------------------------- the USB data disk ---
  # Referenced by UUID because USB enumeration order is not stable, and pointing
  # a format-capable tool at the wrong /dev/sdX is the one failure this
  # migration cannot survive.
  #
  # nofail + device-timeout: if the disk is missing or slow, the Pi still boots
  # and stays reachable over SSH rather than dropping to an emergency shell
  # where it cannot be helped remotely.
  #
  # There is deliberately NO disko module and NO autoFormat/autoResize here.
  fileSystems."/srv/timemachine" = {
    device = "/dev/disk/by-uuid/0adbb212-cb0d-4371-b452-940540914211";
    fsType = "ext4";
    options = [
      "nofail"
      "noatime"
      "x-systemd.device-timeout=30s"
    ];
  };

  # Must match the Debian install exactly -- continuity decision 2.
  users.groups.timemachine.gid = 1001;
  users.users.timemachine = {
    isNormalUser = true;
    uid = 1001;
    group = "timemachine";
    home = "/home/timemachine";
    createHome = true;
  };

  # ------------------------------------------------------------ Time Machine ---
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "server string" = "raspberrypi";
        "security" = "user";
        # LAN only. This share must never be reachable through the Azure edge;
        # the tunnel carries no SMB by design.
        "hosts allow" = "192.168.5. 127.0.0.1 localhost";
        "hosts deny" = "0.0.0.0/0";
      };
      backups = {
        "comment" = "Backups";
        "path" = "/srv/timemachine";
        "valid users" = "timemachine";
        "read only" = "no";
        # vfs_fruit advertises the Time Machine capability. Without
        # `fruit:time machine = yes` macOS will not offer this share as a
        # backup destination at all.
        "vfs objects" = "catia fruit streams_xattr";
        "fruit:time machine" = "yes";
      };
    };
  };

  # Avahi advertises the share so macOS discovers it. LAN only.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      userServices = true;
    };
  };

  # Databases and dumps must NOT live on the shared USB spindle. vid-stream
  # co-hosts here after P3.2, and putting PostgreSQL/SQLite on the same disk as
  # Time Machine writes is exactly the contention the plan's load test targets.
  systemd.tmpfiles.rules = [
    "d /var/lib/vid-stream 0750 root root -"
  ];

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = lib.mkForce "no";
    };
  };

  security.sudo.wheelNeedsPassword = false;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = { inherit inputs outputs; };
  home-manager.users.sspeaks = { ... }: {
    imports = [ ../../home/sspeaks-bare.nix ];
  };

  time.timeZone = "America/Los_Angeles";
  # hosts/common/global already sets 23.05; these are new hosts so a newer
  # stateVersion is correct, but it must override rather than conflict.
  system.stateVersion = lib.mkForce "25.11";
}
