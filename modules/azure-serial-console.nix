{ config, lib, pkgs, ... }:

let
  cfg = config.services.azureSerialConsole;
in
{
  # Provision serial recovery before a networking or SSH failure: ttyS0 needs
  # kernel output, a getty, and a password-bearing account (SSH keys cannot
  # authenticate a serial login). The serial boot menu also allows recovery
  # from a broken kernel or generation.
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
        File containing the rescue account's password hash. Set
        `neededForUsers = true` on its sops secret so it exists before user creation.
        Null keeps the account locked for image builds; deploy the hash after
        first boot, once the host's key is registered in `.sops.yaml`.
      '';
    };

    bootMenuTimeout = lib.mkOption {
      type = lib.types.int;
      default = 10;
      description = ''
        Seconds the boot menu waits. Allow enough time to attach the Azure
        Serial Console and select a generation.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Put serial output before other console parameters.
    boot.kernelParams = lib.mkBefore [
      "console=ttyS0,115200n8"
      "earlyprintk=ttyS0,115200"
    ];

    # Kernel output alone does not provide a login prompt.
    systemd.services."serial-getty@ttyS0" = {
      enable = true;
      wantedBy = [ "getty.target" ];
      # Allow detaching and reconnecting through the Azure portal.
      serviceConfig.Restart = "always";
    };

    users.users.${cfg.rescueUser} = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    } // (
      if cfg.passwordHashFile != null
      then { hashedPassword = lib.mkForce null; hashedPasswordFile = cfg.passwordHashFile; }
      # Keep password login locked until the image has a sops identity.
      else { hashedPassword = "!"; }
    );

    # Previous boot entries cover failures that a running rollback timer cannot.
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
