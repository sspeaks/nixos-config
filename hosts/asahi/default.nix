{ config, pkgs, lib, inputs, ... }:
let
  enableWireguard = true;
in

{
  imports = [
    ../common/global
    ../common/users/sspeaks
    ./hardware-config.nix
    inputs.nixos-apple-silicon.nixosModules.apple-silicon-support
  ];

  # WireGuard VPN with kill switch
  sops.secrets.wireguard-private-key = lib.mkIf enableWireguard {
    sopsFile = ../../secrets/asahi.yaml;
  };

  networking.wg-quick.interfaces.wg0 = lib.mkIf enableWireguard {
    address = [ "10.100.0.3/24" ];
    dns = [ "1.1.1.1" ];
    privateKeyFile = config.sops.secrets.wireguard-private-key.path;

    # Kill switch: only allow traffic through WireGuard
    postUp = ''
      ${pkgs.iptables}/bin/iptables -I OUTPUT ! -o wg0 -m mark ! --mark $(${pkgs.wireguard-tools}/bin/wg show wg0 fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
      ${pkgs.iptables}/bin/ip6tables -I OUTPUT ! -o wg0 -m mark ! --mark $(${pkgs.wireguard-tools}/bin/wg show wg0 fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
    '';
    preDown = ''
      ${pkgs.iptables}/bin/iptables -D OUTPUT ! -o wg0 -m mark ! --mark $(${pkgs.wireguard-tools}/bin/wg show wg0 fwmark) -m addrtype ! --dst-type LOCAL -j REJECT || true
      ${pkgs.iptables}/bin/ip6tables -D OUTPUT ! -o wg0 -m mark ! --mark $(${pkgs.wireguard-tools}/bin/wg show wg0 fwmark) -m addrtype ! --dst-type LOCAL -j REJECT || true
    '';

    peers = [
      {
        publicKey = "vq/1shvvFP1lTc7TjdAhIJDEz7hh1Bijv5QwlJz4ND0=";
        allowedIPs = [ "0.0.0.0/0" "::/0" ];
        endpoint = "13.91.123.214:51820";
        persistentKeepalive = 25;
      }
    ];
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  home-manager.backupFileExtension = "bk";
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;

  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  networking.wireless.iwd = {
    enable = true;
    settings.General.EnableNetworkConfiguration = true;
  };
  hardware.asahi.peripheralFirmwareDirectory = ./firmware;
  hardware.asahi.enable = true;
  hardware.asahi.setupAsahiSound = true;

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  hardware.graphics.enable = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true;  # Required for BLE FIDO2/passkey (caBLE hybrid transport)
        KernelExperimental = true;  # Enable kernel-level BLE experimental features
      };
    };
  };

  # Blueman service (provides root-level D-Bus mechanism for blueman-applet)
  services.blueman.enable = true;

  # Allow non-root access to /dev/uhid (required for FIDO2/passkey caBLE hybrid transport)
  services.udev.extraRules = ''
    KERNEL=="uhid", GROUP="input", MODE="0660"
  '';

  programs.hyprland.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
  };
  environment.systemPackages = with pkgs; [
    chromium
    iwgtk
    vscode
  ] ++ lib.optionals enableWireguard [
    wireguard-tools
  ];

  networking = {
    hostName = "asahi-mpb";
    firewall.enable = true;
  };

  services.logind.settings.Login.HandleLidSwitch = "suspend";
  services.logind.settings.Login.HandleLidSwitchDocked = "ignore";
  services.logind.settings.Login.HandleLidSwitchExternalPower = "lock";

  services.openssh.enable = false;
  services.openssh.settings.X11Forwarding = false;

  # Docker
  virtualisation.docker.enable = true;

  home-manager.useUserPackages = true;
  home-manager.users.sspeaks = { ... }:
    {
      imports = [
        ../../home/sspeaks.nix
        ../../home/features/hyprland
        ../../home/features/alacritty
        ../../home/features/dunst
        ../../home/features/wofi
        ../../home/features/wlogout
        ../../home/features/fonts
        ./waybar.nix
      ];
    };

  # Keyring - auto-unlocks at login for Chromium, git, etc.
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;

  security.sudo.wheelNeedsPassword = false;

  # Zram swap - compresses RAM, better than disk swap on flash storage
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  i18n.defaultLocale = "en_US.UTF-8";

  time.timeZone = "America/Los_Angeles";

  # Power management
  services.power-profiles-daemon.enable = true;

  nixpkgs.hostPlatform = "aarch64-linux";
}

