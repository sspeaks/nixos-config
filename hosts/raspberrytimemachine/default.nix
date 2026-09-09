{ inputs, lib, pkgs, outputs, ... }:
# Time Machine appliance: the OS boots from SD; backups belong on USB.
# Never format, repartition, or write an OS image to the USB backup disk.
# Mount it by UUID and keep SSH reachable when it is absent.
#
# Preserve hostname `raspberrypi`, share `backups`, and timemachine uid/gid
# 1001 for destination identity and existing file ownership. The flake name
# `raspberrytimemachine` is deliberately different from the guest hostname.
{
  imports = [
    ../common/global
    ../common/users/sspeaks
    ../common/users/sspeaks/authorized-keys.nix
    # Use stock sd-image-aarch64 firmware, not nixpi's raspberry-pi-4 profile.
    inputs.home-manager.nixosModules.home-manager
  ];

  nixpkgs.hostPlatform = "aarch64-linux";
  nixpkgs = {
    overlays = lib.mkDefault outputs.lib.overlayList;
    config.allowUnfree = lib.mkDefault true;
  };

  # The stock SD image supplies U-Boot and a selective firmware set.
  # The raspberry-pi-4 profile overrides firmware population; combining them
  # risks a missing bootloader or an overflowing firmware partition.
  # ZFS adds image size and build work without serving this appliance.
  boot.supportedFilesystems.zfs = lib.mkForce false;

  # Leave headroom for firmware growth.
  sdImage.firmwareSize = 256;


  networking = {
    hostName = "raspberrypi";
    useDHCP = lib.mkDefault true;
  };

  users.groups.timemachine.gid = 1001;
  users.users.timemachine = {
    isNormalUser = true;
    uid = 1001;
    group = "timemachine";
    home = "/home/timemachine";
    createHome = true;
  };

  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "server string" = "raspberrypi";
        "security" = "user";
        # LAN only; never expose SMB through the public edge.
        "hosts allow" = "192.168.5. 127.0.0.1 localhost";
        "hosts deny" = "0.0.0.0/0";
      };
      backups = {
        "comment" = "Backups";
        "path" = "/srv/timemachine";
        "valid users" = "timemachine";
        "read only" = "no";
        # Advertise this share as a Time Machine destination.
        "vfs objects" = "catia fruit streams_xattr";
        "fruit:time machine" = "yes";
      };
    };
  };

  # LAN discovery needs explicit _adisk records for the `backups` volume.
  # _device-info identifies it as a Time Capsule in macOS.
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

  # Reserve USB for Time Machine, not databases or video workloads (vidbox).
  # Backups must not fall through to the SD-backed mountpoint when USB is absent.
  # nofail and a bounded device wait keep the host reachable without the disk.
  # UUID matching avoids device reordering and duplicate SD/USB root labels.
  fileSystems."/srv/timemachine" = {
    device = "/dev/disk/by-uuid/7d1f6fce-dee0-49cc-bd47-98ed7dd4438e";
    fsType = "ext4";
    options = [ "nofail" "noatime" "x-systemd.device-timeout=15s" ];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/samba/private 0700 root root -"
    "d /srv/timemachine 0755 timemachine timemachine -"
  ];

  # Restore the existing password and SID so macOS can reuse saved credentials.
  # Never overwrite an existing passdb or subsequent local password changes.
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
  # Preserve this host's initial state version over the shared default.
  system.stateVersion = lib.mkForce "25.11";
}
