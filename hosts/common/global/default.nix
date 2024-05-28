{ inputs, outputs, lib, ... }:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ../sops.nix
  ];
  home-manager.useGlobalPkgs = true;
  home-manager.extraSpecialArgs = {
    inherit inputs outputs;
  };
  nixpkgs = {
    overlays = outputs.overlays;
    config = {
      allowUnfree = true;
    };
  };

  services.openssh.enable = lib.mkDefault true;
  services.openssh.settings.X11Forwarding = lib.mkDefault false;

  hardware.enableRedistributableFirmware = true;

  system.stateVersion = "23.05";
}
