{ config, pkgs, inputs, ... }:

{
  imports = [
    ../common/global
    ../common/users/sspeaks
    ./hardware-config.nix

    inputs.vscode-server.nixosModules.default
    ({ config, pkgs, ... }: {
      services.vscode-server.enable = true;
    })
  ];

  networking = {
    hostName = "nixpi";
  };

  security.sudo.wheelNeedsPassword = false;

  time.timeZone = "America/Los_Angeles";

  nixpkgs.hostPlatform = "aarch64-linux";
}

