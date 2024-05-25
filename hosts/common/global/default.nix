{ inputs, outputs, ... }:
{
  imports = [ inputs.home-manager.nixosModules.home-manager ];
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

  services.openssh.enable = true;
  services.openssh.settings.X11Forwarding = true;

  hardware.enableRedistributableFirmware = true;

  system.stateVersion = "23.05";
}
