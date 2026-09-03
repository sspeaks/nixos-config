{ pkgs, lib, inputs, config, ... }:

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


  # P2.3 — home-initiated tunnel to the old Azure edge.
  #
  # This INVERTS the previous topology. Before, `blog` dialled OUT to a
  # residential endpoint, which meant the old edge depended on the home IP
  # staying reachable: a router reboot or an ISP address change broke the
  # fallback path, and the residential address had to be written into the
  # edge's config. Now the Pi dials the edge's STATIC Azure address, so the
  # home address is never needed anywhere and can change freely.
  #
  # persistentKeepalive is what makes an outbound-only tunnel survive NAT:
  # without it the home NAT mapping expires and the edge can no longer reach
  # back to deliver traffic.
  sops.secrets.wg-edge-private-key = {
    format = "yaml";
    sopsFile = ../../secrets/nixpi5.yaml;
    mode = "0400";
    owner = "root";
  };

  networking.wireguard.enable = true;
  networking.wireguard.interfaces.wg-edge = {
    ips = [ "10.10.0.2/32" ];
    privateKeyFile = config.sops.secrets.wg-edge-private-key.path;
    peers = [{
      publicKey = "gTkLAa4pN+STVJDde9wWI4QDi4AFBn/ArTx6ul/PFAU=";
      endpoint = "40.86.75.95:51820";
      # Only the edge's own overlay address. NOT a LAN prefix: the edge must
      # never be able to route into 192.168.5.0/24, which is what the P1.4
      # narrowing of the old tunnel was about.
      allowedIPs = [ "10.10.0.1/32" ];
      persistentKeepalive = 25;
    }];
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

