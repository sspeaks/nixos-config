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
    overlays = builtins.attrValues outputs.overlays;
    config = {
      allowUnfree = true;
    };
  };

  services.openssh.enable = lib.mkDefault true;
  services.openssh.settings.X11Forwarding = lib.mkDefault true;

  hardware.enableRedistributableFirmware = true;

  system.stateVersion = "23.05";
}
