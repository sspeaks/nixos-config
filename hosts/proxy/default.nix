{ inputs, lib, config, outputs, ... }:
# Public Azure edge using a specialized Arm64 VHD, with no first-boot provisioning.
{
  imports = [
    ../common/global
    ../common/users/sspeaks
    ../common/users/sspeaks/authorized-keys.nix
    ../../modules/azure-serial-console.nix
    ./edge.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  nixpkgs.hostPlatform = "aarch64-linux";
  nixpkgs = {
    overlays = lib.mkDefault outputs.lib.overlayList;
    config.allowUnfree = lib.mkDefault true;
  };

  networking.hostName = "proxy";

  # Gen2 requires UEFI/GPT; Azure requires the builder's fixed-size VHD format.
  virtualisation.azureImage = {
    vmGeneration = "v2";
    bootSize = 256;
  };
  # Fit the 16 GiB OS disk with a predictable upload size.
  virtualisation.diskSize = 15 * 1024;

  # The image cannot set the target's EFI variables; use /EFI/BOOT/BOOTAA64.EFI.
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";
    efiInstallAsRemovable = true;
    # The 256 MiB ESP holds ~236 MiB after GRUB's own files, while each aarch64
    # generation costs ~87 MiB (61 MiB uncompressed Image + 25 MiB initrd).
    # install-grub copies the incoming generation before pruning obsolete ones,
    # so peak usage is (configurationLimit + 1) generations: 2 fits, 3 does not.
    # Roll back over SSH instead (nix-env --rollback on the system profile plus
    # switch-to-configuration boot); nix.gc never reclaims ESP space.
    configurationLimit = 1;
  };
  boot.loader.efi.canTouchEfiVariables = false;

  # Keep systemd-networkd the sole DHCP owner, without cloud-init competing.
  services.cloud-init.network.enable = lib.mkForce false;
  networking.useNetworkd = true;
  networking.useDHCP = false;

  systemd.network = {
    enable = true;
    networks."10-azure-primary" = {
      matchConfig.Name = "eth0 en*";
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = false;
      };
      dhcpV4Config.UseDNS = true;
      linkConfig.RequiredForOnline = "routable";
    };
  };

  # Disable provisioning: specialized images receive no first-boot data.
  # Retain waagent for VMAccess recovery. Replacing its overlay requires a
  # separate runtime recovery check; evaluation cannot establish that it works.
  services.waagent.settings = {
    Provisioning.Enable = false;
    ResourceDisk.Format = false;
    ResourceDisk.EnableSwap = false;
  };

  # Specialized images receive no Azure-injected SSH key; bake in access keys.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = lib.mkForce "no";
      X11Forwarding = false;
    };
  };

  # Lock rescue access without a SOPS identity; edge.nix supplies the hash.
  services.azureSerialConsole = {
    enable = true;
    passwordHashFile = null;
  };

  # Deploy the public edge deliberately from reviewed commits.
  system.autoUpgrade.enable = lib.mkForce false;
  # Avoid swap consuming the small root disk and adding billed writes.
  swapDevices = lib.mkForce [ ];

  # The 15 GiB root cannot carry the fleet-wide 14 day retention, and a weekly
  # timer leaves no chance to recover before the next deploy substitutes a
  # closure. min-free/max-free additionally collects mid-substitution, which is
  # the only thing that runs during an update-fleet prefetch.
  nix.gc = {
    dates = lib.mkForce "daily";
    options = lib.mkForce "--delete-older-than 7d";
  };
  nix.settings.min-free = 1024 * 1024 * 1024;
  nix.settings.max-free = 3 * 1024 * 1024 * 1024;

  security.sudo.wheelNeedsPassword = false;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = { inherit inputs outputs; };
  home-manager.users.sspeaks = { ... }: {
    imports = [ ../../home/sspeaks-bare.nix ];
  };

  # 80/443 for the public edge; 51820/udp for home peers dialling out.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 80 443 ];
    allowedUDPPorts = [ 51820 ];
  };

  time.timeZone = "America/Los_Angeles";
  # Preserve this host's initial state version over the shared default.
  system.stateVersion = lib.mkForce "25.11";
}
