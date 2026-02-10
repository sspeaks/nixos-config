{ pkgs, inputs, ... }:

{
  imports = [
    ../common/global
    ../common/users/sspeaks
    inputs.home-manager.nixosModules.home-manager
    ./hardware-configuration.nix
    inputs.determinate.nixosModules.default
    #    ../../modules/postgresql.nix
    ./authentik.nix
    ./home-assistant.nix
    ./webmailclient.nix
  ];

  users.users.sspeaks.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC+ZOxlbIpvXB6NDFUqX2OGGbEyIfA+7Zd6mxq78e5abuYD80bMyJdAS1H/05oBKFI5zV45Bb39DXV9HHxVJXVKQ35bs3sfrf6myTK94grgHbCn3o0pru+PsdtXBnCjsC8EMS9pua17ZPyLgCy1jYxGocCoYpxZoP1CLV+LkHauL2IxXAvZkU+W7pHgphF1jnUNjEl52TY++W5BfEJ6xvCUKj7xDMyXpAmNNdpohFpL2ughbdkL5F8s7O/RQFfzh7O13hWlbdgLHMOcoA3tuLSd5pTZjHvqEs0n1CLT/SnvONtD9uNUMGdLGisMydRVFYmOOJ9LxF1pdEvowExbMvAEa0a7nFLASnmnxqzL1lbFxvUQ5p55s3CO4y1B72lpIRRAwuvOUBrpHw83zq6FQ8Z0C2bbmJa/YFOPre6GPw6WbnvUhsYegvxBEHFPUf5zFBqzZGfjbneRptexq8Yl7vtbXP3jyRMj59IumRBOAKHXQj/6fxo4n3WnkiXGmaWh2pk= sspeaks@sspeaks-pc"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDB8f/1dOhzPDyPYAV7M6n4bPpOd077sf86y0mrM2dpEHxIJE7+imKR2U8XlHREbWH+Z9eS1AbHRPl8ULj42NXORLCmUAdzO9r56We+2tjSueQBhSXBvMnsNE6aEOrxyr3bgIP6qPcDanwCgxHDI19UI17lu0taPNDxy8x/QJqmnDB3X0RS4N9WZePmfKT1/2zzy6y9pMbl9AhOneBOe4kQRPFNIH2keiOb5W0h83ExlWHyZ83rg78yTNj4f6K2u/pTkIUNnrBXoRA2Fu8ByhJ3+I5OYlBsUsFV7RD1OvLqKEp+cfQU1+rdOukvqaUIVBKT3XrsxkDDM1Vxe00VLvIT sspeaks@seths-mbp.lan"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDhirGFWX+DgCrQkI1Xy7qI2k9fMA/AWIRVi4lnPQwCn+eDM/OFt3K9vRkbRtzAD7bFHw1PVtjpbrch3IYoGTt+llWJO0BHqP6vRKkzmOqGXkdCspKojw3z16uHsI/mGA0Py7vVPxOo4OBcTX5WM9+Mp7OHYqxXmovxeMTXxHRI51OXtpAgyW+YO0oLPuwkSPcglLU3+XzX/wYb/Tf6gOta7MkXLZPQRES/8fAFGBbNmkTonM8RBbvkFnv9a7Xjt8rAlUAWBo5UAJHdhDJgZ44BDXw/ohn+IMEZulApBFlogBwLXN6mSCMd/NfVAkxvACbNg+jVsiXxTydlHKifxRHAoNvUsE+4dtlC6cyJtwZoPuu++iqDRu9Skzpm7idet+pQoSgrqAuB4sWVuAk1CyGe0pXCKRX9mXMngmCCZPo5d0w9hFlY+JJVKjYypNFbim9UyQW/RZ8qEXPpz5GVDC+2q8ov+r1C+QI6NGORrQgXuT4yHMIzMNx0sZ2QlS/Gtwc= seth@sspeaks-pc-windows"
  ];

  networking = {
    hostName = "nixpi5";
  };

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

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.sspeaks = { ... }: {
    imports = [ ../../home/sspeaks.nix ];
    programs.starship.settings.hostname.disabled = false;
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

