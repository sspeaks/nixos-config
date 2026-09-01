{ pkgs, lib, inputs, ... }:

{
  imports = [
    ../common/global
    ../common/users/sspeaks
    ../common/users/sspeaks/authorized-keys.nix
    inputs.home-manager.nixosModules.home-manager
    ./hardware-configuration.nix
    inputs.determinate.nixosModules.default
    #    ../../modules/postgresql.nix
    ./authentik.nix
    ./home-assistant.nix
    ./go2rtc.nix
    ./webmailclient.nix
    # garage-monitor input is currently disabled — uncomment in flake.nix to restore
    # inputs.garage-monitor.nixosModules.default
    # ./garage-monitor.nix
  ];

  networking = {
    hostName = "nixpi5";
  };

  boot.loader.raspberry-pi.bootloader = "kernel";

  environment.systemPackages = [
    pkgs.libraspberrypi
    #    pkgs.docker-compose
    #    pkgs.linuxPackages_rpi5.v4l2loopback
    /*     pkgs.linuxPackages.v4l2loopback */
  ];

  nix.settings.trusted-users = [ "sspeaks" "root" ];
  nix.settings.lazy-trees = true;

  # networking.wireless.iwd = {
  #   enable = true;
  #   settings.General.EnableNetworkConfiguration = true;
  # };
  system.autoUpgrade = {
    enable = true;
    operation = "boot";
    flake = "github:sspeaks/nixos-config#nixpi5";
    dates = "04:30";
    randomizedDelaySec = "15min";
    allowReboot = true;
  };


  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.sspeaks = { ... }: {
    imports = [ ../../home/sspeaks-bare.nix ];
    programs.starship.settings.hostname.disabled = false;
    home.enableNixpkgsReleaseCheck = false;
  };

  security.sudo.wheelNeedsPassword = false;
  services.openssh.settings.X11Forwarding = true;

  #  virtualisation.docker.enable = true;

  time.timeZone = "America/Los_Angeles";
  console = {
    font = "ter-i24b";
    packages = with pkgs; [ terminus_font ];
    earlySetup = true;
  };
  #  services.xserver.enable = true;
  #  programs.sway.enable = true;
  #  services.xserver.displayManager.gdm.enable = true;
  nixpkgs.hostPlatform = "aarch64-linux";
}

