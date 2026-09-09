{ pkgs, inputs, ... }:

{
  imports = [
    ../common/global
    ../common/users/sspeaks
    ../common/users/sspeaks/authorized-keys.nix
    ./hardware-config.nix
    ./networking.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  networking = {
    hostName = "nixpi";
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.sspeaks = { ... }: {
    imports = [ ../../home/sspeaks.nix ];
    programs.starship.settings.hostname.disabled = false;
  };

  security.sudo.wheelNeedsPassword = false;
  services.openssh.settings.X11Forwarding = true;

  time.timeZone = "America/Los_Angeles";
  console = {
    font = "ter-i32b";
    packages = with pkgs; [ terminus_font ];
    earlySetup = true;
  };
  #  services.xserver.enable = true;
  #  programs.sway.enable = true;
  #  services.xserver.displayManager.gdm.enable = true;
  nixpkgs.hostPlatform = "aarch64-linux";
}

