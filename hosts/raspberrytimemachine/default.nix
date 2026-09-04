{ inputs, lib, pkgs, outputs, ... }:
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

  # sd-image-aarch64.nix imports profiles/base.nix, which turns on ZFS support
  # and `hardware.enableAllHardware`. Both break the build on this Pi:
  #
  #   * ZFS drags its kernel modules into the image and they fail to build
  #     against the Raspberry Pi 6.18 kernel.
  #   * enableAllHardware requests a broad module list intended for generic
  #     install media, including `dw-hdmi`, which the Pi kernel does not build:
  #       modprobe: FATAL: Module dw-hdmi not found
  #     That fails `modules-shrunk` and takes the whole SD image with it.
  #
  # Neither is wanted here. This is a single-purpose appliance on known
  # hardware with one ext4 USB disk and one ext4 SD card -- not install media
  # that has to boot on an unknown machine. The Pi-specific modules it does
  # need come from ../nixpi/hardware-config.nix (nixos-hardware raspberry-pi-4).
  boot.supportedFilesystems.zfs = lib.mkForce false;
  hardware.enableAllHardware = lib.mkForce false;

  # Restore the U-Boot firmware chain that sd-image-aarch64.nix provides.
  #
  # This host stacks two modules that both claim `sdImage`:
  #   * sd-image-aarch64.nix populates the FAT partition for the generic
  #     aarch64 chain -- firmware loads u-boot-rpi4.bin, U-Boot then reads
  #     /boot/extlinux/extlinux.conf off the ext4 root and boots the system.
  #   * nixos-hardware's raspberry-pi-4 module replaces
  #     populateFirmwareCommands with a verbatim copy of the Raspberry Pi OS
  #     boot directory, whose config.txt carries no `kernel=` line at all.
  #
  # nixos-hardware wins the merge, so the built image shipped start4.elf and
  # every .dtb but NO kernel and NO U-Boot. The Pi 4 firmware then falls back
  # to looking for kernel8.img, does not find it, and halts with the green-LED
  # "kernel image not found" code (7 short flashes) -- which is exactly how
  # this failed on `.106`, and it is not an EEPROM fault.
  #
  # The extlinux side of the image was always correct, so only the FAT
  # partition needed fixing. This reproduces the firmware layout running on
  # nixpi4-bare, which is the same Pi 4 hardware and boots reliably.
  sdImage.populateFirmwareCommands =
    let
      configTxt = pkgs.writeText "config.txt" ''
        [pi3]
        kernel=u-boot-rpi3.bin

        [pi02]
        kernel=u-boot-rpi3.bin

        [pi4]
        kernel=u-boot-rpi4.bin
        enable_gic=1
        armstub=armstub8-gic.bin

        disable_overscan=1
        arm_boost=1

        [cm4]
        otg_mode=1

        [all]
        arm_64bit=1
        # U-Boot requires this whether or not the UART is actually used, and it
        # is also what makes the serial console usable for recovery here.
        enable_uart=1
        avoid_warnings=1
      '';
    in
    lib.mkForce ''
      (cd ${pkgs.raspberrypifw}/share/raspberrypi/boot && cp bootcode.bin fixup*.dat start*.elf $NIX_BUILD_TOP/firmware/)
      cp ${configTxt} firmware/config.txt
      cp ${pkgs.ubootRaspberryPi3_64bit}/u-boot.bin firmware/u-boot-rpi3.bin
      cp ${pkgs.ubootRaspberryPi4_64bit}/u-boot.bin firmware/u-boot-rpi4.bin
      cp ${pkgs.raspberrypi-armstubs}/armstub8-gic.bin firmware/armstub8-gic.bin
      cp ${pkgs.raspberrypifw}/share/raspberrypi/boot/bcm2711-rpi-4-b.dtb firmware/
    '';

  networking = {
    hostName = "raspberrypi"; # continuity decision 1 -- see header
    useDHCP = lib.mkDefault true;
  };

  # ------------------------------------------------------- the USB data disk ---
  # BOOT-FROM-USB LAYOUT.
  #
  # The owner had no spare SD card and was remote, so the SD card is NOT
  # reimaged. Instead the whole NixOS image is written to the USB disk and the
  # Pi's EEPROM boot order is set to try USB before SD. That leaves the Debian
  # SD card completely untouched and still bootable, so a USB that fails to
  # boot simply falls through to Debian -- the pre-migration state -- with no
  # physical access required.
  #
  # Consequence: the USB disk is now the ROOT device, expanded to fill the
  # drive on first boot. There is no separate data partition to mount, so the
  # previous by-UUID mount of sda2 is gone along with the 593 GB of Time
  # Machine history it held. The owner explicitly accepted that loss:
  # "I dont care if it's risky or causes time machine backup dataloss.. I can
  # always do another backup".
  #
  # /srv/timemachine is therefore a plain directory on the expanded root.
  # Ownership must still be uid/gid 1001 so the restored Samba account can
  # write to it.

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
  #
  # The extraServiceFiles block is NOT optional decoration -- it is copied from
  # the working Debian install and is what makes macOS treat this as a Time
  # Machine destination at all:
  #   _adisk._tcp with adVN=backups,adVF=0x82  -> "this host offers a Time
  #     Machine volume named `backups`". Without it macOS may never offer the
  #     destination in System Settings even though the share mounts fine.
  #   _device-info._tcp model=TimeCapsule8,119 -> macOS shows it as a Time
  #     Capsule rather than a generic file server.
  # NixOS' samba/avahi modules do not publish these records on their own.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      userServices = true;
    };
    extraServiceFiles.samba = ''
      <?xml version="1.0" standalone='no'?><!--*-nxml-*-->
      <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
      <service-group>
        <name replace-wildcards="yes">%h</name>
        <service>
          <type>_smb._tcp</type>
          <port>445</port>
        </service>
        <service>
          <type>_device-info._tcp</type>
          <port>9</port>
          <txt-record>model=TimeCapsule8,119</txt-record>
        </service>
        <service>
          <type>_adisk._tcp</type>
          <port>9</port>
          <txt-record>dk0=adVN=backups,adVF=0x82</txt-record>
          <txt-record>sys=adVF=0x100</txt-record>
        </service>
      </service-group>
    '';
  };

  # Databases and dumps must NOT live on the shared USB spindle. vid-stream
  # co-hosts here after P3.2, and putting PostgreSQL/SQLite on the same disk as
  # Time Machine writes is exactly the contention the plan's load test targets.
  systemd.tmpfiles.rules = [
    "d /var/lib/vid-stream 0750 root root -"
    "d /var/lib/samba/private 0700 root root -"
    # Time Machine target lives on the expanded root now. uid/gid 1001 must
    # match the restored Samba account or the share is unwritable.
    "d /srv/timemachine 0755 timemachine timemachine -"
  ];

  # Restore the Samba credential database captured from the Debian install.
  #
  # Why this matters: macOS has the Time Machine password saved in its keychain
  # against this server. A fresh Samba install has an empty passdb, so backups
  # would fail authentication until someone re-entered credentials by hand --
  # and a forgotten manual step here means G-TIME-MACHINE cannot pass.
  # Restoring passdb.tdb/secrets.tdb preserves the EXISTING password and the
  # timemachine account's SID, so macOS reconnects with what it already knows.
  #
  # Runs once: it refuses to overwrite an existing passdb, so a later
  # password change made on this host is never clobbered by a redeploy.
  systemd.services.samba-passdb-restore = {
    description = "Restore Samba passdb captured from the Debian install";
    wantedBy = [ "multi-user.target" ];
    before = [ "samba-smbd.service" ];
    unitConfig.ConditionPathExists = "!/var/lib/samba/private/passdb.tdb";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail
      seed=/var/lib/samba-seed/samba-private.tar
      if [ ! -f "$seed" ]; then
        echo "no seed tarball at $seed; leaving passdb empty" >&2
        echo "Samba password must then be set manually: smbpasswd -a timemachine" >&2
        exit 0
      fi
      install -d -m 0700 /var/lib/samba/private
      ${pkgs.gnutar}/bin/tar -C /var/lib/samba/private -xf "$seed"
      chmod 0600 /var/lib/samba/private/passdb.tdb /var/lib/samba/private/secrets.tdb
      echo "restored Samba passdb from $seed"
    '';
  };

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
