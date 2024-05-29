{ inputs, outputs, pkgs, lib, config, ... }:
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

  sops.secrets.open-ai-api-key = {
#    neededForUsers = true;
    mode = "444";
    owner = "sspeaks";
    group = "users";
  };
  environment.systemPackages = [
    (pkgs.askGPT4.overrideAttrs (_: rec {
      OPEN_AI_KEY_FILE = config.sops.secrets.open-ai-api-key.path;
      postFixup = ''
        wrapProgram $out/bin/askGPT4 \
        --set OPEN_AI_KEY ${OPEN_AI_KEY_FILE}
      '';

    }))

  ];
  services.openssh.enable = lib.mkDefault true;
  services.openssh.settings.X11Forwarding = lib.mkDefault false;

  hardware.enableRedistributableFirmware = true;

  system.stateVersion = "23.05";
}
