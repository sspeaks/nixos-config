{ config, pkgs, ... }:

{
  imports = [ ./modules/minecraft.nix ];
  boot = {
    kernelPackages = pkgs.linuxKernel.packages.linux_rpi4;
    initrd.availableKernelModules = [ "xhci_pci" "usbhid" "usb_storage" ];
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };
  };
  swapDevices = [{ device = "/swapfile"; size = 4096; }];
  nix.settings.trusted-users = [ "sspeaks" ];
  nix.package = pkgs.nixFlakes;
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [ vim screen ];

  services.openssh.enable = true;
  services.openssh.settings.X11Forwarding = true;

  programs.zsh.enable = true;
  users.mutableUsers = false;
  users.users.sspeaks = {
    shell = pkgs.zsh;
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    password = "DUMMY_PASSWORD";
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC+ZOxlbIpvXB6NDFUqX2OGGbEyIfA+7Zd6mxq78e5abuYD80bMyJdAS1H/05oBKFI5zV45Bb39DXV9HHxVJXVKQ35bs3sfrf6myTK94grgHbCn3o0pru+PsdtXBnCjsC8EMS9pua17ZPyLgCy1jYxGocCoYpxZoP1CLV+LkHauL2IxXAvZkU+W7pHgphF1jnUNjEl52TY++W5BfEJ6xvCUKj7xDMyXpAmNNdpohFpL2ughbdkL5F8s7O/RQFfzh7O13hWlbdgLHMOcoA3tuLSd5pTZjHvqEs0n1CLT/SnvONtD9uNUMGdLGisMydRVFYmOOJ9LxF1pdEvowExbMvAEa0a7nFLASnmnxqzL1lbFxvUQ5p55s3CO4y1B72lpIRRAwuvOUBrpHw83zq6FQ8Z0C2bbmJa/YFOPre6GPw6WbnvUhsYegvxBEHFPUf5zFBqzZGfjbneRptexq8Yl7vtbXP3jyRMj59IumRBOAKHXQj/6fxo4n3WnkiXGmaWh2pk= sspeaks@sspeaks-pc"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDB8f/1dOhzPDyPYAV7M6n4bPpOd077sf86y0mrM2dpEHxIJE7+imKR2U8XlHREbWH+Z9eS1AbHRPl8ULj42NXORLCmUAdzO9r56We+2tjSueQBhSXBvMnsNE6aEOrxyr3bgIP6qPcDanwCgxHDI19UI17lu0taPNDxy8x/QJqmnDB3X0RS4N9WZePmfKT1/2zzy6y9pMbl9AhOneBOe4kQRPFNIH2keiOb5W0h83ExlWHyZ83rg78yTNj4f6K2u/pTkIUNnrBXoRA2Fu8ByhJ3+I5OYlBsUsFV7RD1OvLqKEp+cfQU1+rdOukvqaUIVBKT3XrsxkDDM1Vxe00VLvIT sspeaks@seths-mbp.lan"
    ];
  };
  security.sudo.wheelNeedsPassword = false;

  hardware.enableRedistributableFirmware = true;
  time.timeZone = "America/Los_Angeles";
  system.stateVersion = "23.05";
}

