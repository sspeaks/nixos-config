{ config, lib, pkgs, ... }:

let
  cfg = config.services.azureSerialConsole;
in
{
  # P1.3 Azure lockout guard.
  #
  # Azure has no physical console and no link-local rescue path. If a change
  # breaks sshd, the firewall, or networking, the ONLY remaining way in is the
  # Azure Serial Console -- and that only helps if the guest was already
  # configured to talk to ttyS0 and to offer a login there. Configuring it
  # after you are locked out is not possible.
  #
  # Three things must all be true, which is why they live together here:
  #
  #   1. The kernel must emit to ttyS0, or the console shows nothing.
  #   2. A getty must run on ttyS0, or there is nothing to log into.
  #   3. A local account with a PASSWORD must exist. SSH keys are useless over
  #      a serial line, and the normal admin account is key-only, so without a
  #      dedicated password-bearing rescue account the console is a read-only
  #      spectator to your own outage.
  #
  # The bootloader is also made serial-visible so a bad kernel or a bad
  # generation can be escaped by picking a previous entry from the boot menu,
  # which a running-system timer cannot help with.
  options.services.azureSerialConsole = {
    enable = lib.mkEnableOption "Azure Serial Console recovery path";

    rescueUser = lib.mkOption {
      type = lib.types.str;
      default = "serial-rescue";
      description = "Local account usable over the serial console.";
    };

    passwordHashFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a file containing the rescue account's password hash. Must be
        available before users are created, so the corresponding sops secret
        needs `neededForUsers = true`.

        May be null, which creates the account LOCKED. That is the correct
        state for a freshly built specialized image: the host's SSH key does
        not exist until it first boots, so sops cannot yet decrypt anything for
        it. The account is created locked in the image and the real hash is
        deployed once the host key is known and added to `.sops.yaml`.
      '';
    };

    bootMenuTimeout = lib.mkOption {
      type = lib.types.int;
      default = 10;
      description = ''
        Seconds the boot menu waits. Must be long enough to actually attach the
        Azure Serial Console and press a key; the default of 0-5 is unusable in
        practice because the console takes several seconds to connect.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # mkBefore so these are the first console= arguments the kernel sees.
    boot.kernelParams = lib.mkBefore [
      "console=ttyS0,115200n8"
      "earlyprintk=ttyS0,115200"
    ];

    # Azure's serial console is ttyS0. Without an explicit getty there is
    # nothing listening even though the kernel is emitting.
    systemd.services."serial-getty@ttyS0" = {
      enable = true;
      wantedBy = [ "getty.target" ];
      # Survive the console being detached and reattached, which is normal
      # when connecting from the portal.
      serviceConfig.Restart = "always";
    };

    users.users.${cfg.rescueUser} = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    } // (
      if cfg.passwordHashFile != null
      then { hashedPassword = lib.mkForce null; hashedPasswordFile = cfg.passwordHashFile; }
      # "!" is an invalid hash, so password auth always fails: the account
      # exists and is ready, but cannot be logged into until a real hash is
      # deployed. This is deliberate for an image that has no sops identity yet.
      else { hashedPassword = "!"; }
    );

    # Keep a few generations selectable from the boot menu. A boot-time failure
    # is outside any running timer's reach, so the previous generation in the
    # menu is the actual recovery mechanism.
    boot.loader.timeout = lib.mkForce cfg.bootMenuTimeout;

    boot.loader.grub = lib.mkIf config.boot.loader.grub.enable {
      configurationLimit = lib.mkDefault 3;
      extraConfig = ''
        serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1
        terminal_input --append serial
        terminal_output --append serial
      '';
    };

    boot.loader.systemd-boot = lib.mkIf config.boot.loader.systemd-boot.enable {
      configurationLimit = lib.mkDefault 3;
      consoleMode = lib.mkDefault "auto";
    };
  };
}
