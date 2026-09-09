{ pkgs, lib, inputs, config, ... }:

{
  imports = [
    ../common/global
    ../common/users/sspeaks
    ../common/users/sspeaks/authorized-keys.nix
    inputs.home-manager.nixosModules.home-manager
    ./hardware-configuration.nix
    inputs.determinate.nixosModules.default
    ./authentik.nix
    ./home-assistant.nix
    ./go2rtc.nix
    ./webmailclient.nix
    ../../modules/restic-offsite.nix
    # Restore the garage-monitor input in flake.nix before enabling these.
    # inputs.garage-monitor.nixosModules.default
    # ./garage-monitor.nix
  ];

  networking = {
    hostName = "nixpi5";
  };

  boot.loader.raspberry-pi.bootloader = "kernel";

  environment.systemPackages = [
    pkgs.libraspberrypi
  ];

  nix.settings.trusted-users = [ "sspeaks" "root" ];
  nix.settings.lazy-trees = true;

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


  # Dial static edge addresses from home; keepalives preserve the NAT mapping.
  sops.secrets.wg-edge-private-key = {
    format = "yaml";
    sopsFile = ../../secrets/nixpi5.yaml;
    mode = "0400";
    owner = "root";
  };

  # Keep this host's backup repository and password independent of vidbox's,
  # even though both use the same Azure storage account.
  sops.secrets.restic-password = {
    format = "yaml";
    sopsFile = ../../secrets/nixpi5.yaml;
    owner = "root";
    group = "root";
    mode = "0400";
  };
  sops.secrets.restic-azure-environment = {
    format = "yaml";
    sopsFile = ../../secrets/nixpi5.yaml;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  services.resticOffsite = {
    enable = true;
    container = "nixpi5";

    # Dump Authentik's database; copying a live PostgreSQL directory is unsafe.
    postgresDatabases = [ "authentik" ];

    # SQLite .backup includes WAL state that a plain file copy can miss.
    sqliteDatabases = {
      home-assistant = "/var/lib/hass/home-assistant_v2.db";
    };

    paths = [
      # Home Assistant configuration and registries, beyond the recorder DB.
      "/var/lib/hass"
      # DynamicUser state, including Authentik media/certificates and ntfy-sh.
      "/var/lib/private"
      "/var/lib/snappymail"
      # Irreplaceable Time Machine recovery seed, including the Samba passdb.
      "/var/lib/migration-seed"
    ];

    exclude = [
      # Python dependencies and HTTP caches that Home Assistant refetches.
      "/var/lib/hass/deps"
      "/var/lib/hass/.cache"
    ];
  };

  # Intentionally omit model/image caches, camera monitoring frames, and
  # regenerable rspamd/tor state. Add persistent container data explicitly.

  networking.wireguard.enable = true;
  networking.wireguard.interfaces.wg-edge = {
    ips = [ "10.10.0.2/32" ];
    privateKeyFile = config.sops.secrets.wg-edge-private-key.path;
    peers = [
      {
        publicKey = "gTkLAa4pN+STVJDde9wWI4QDi4AFBn/ArTx6ul/PFAU=";
        endpoint = "40.86.75.95:51820";
        # Edge addresses only, never a route to the home LAN.
        allowedIPs = [ "10.10.0.1/32" ];
        persistentKeepalive = 25;
      }
      {
        # Parallel edge tunnels permit DNS-only cutover/rollback; each peer
        # needs a distinct allowedIPs address.
        publicKey = "Sbm2/JkGPNO9LEsrI2oJSHZNIxoOCsf/2l8jwm6AtHM=";
        endpoint = "20.83.103.87:51820";
        allowedIPs = [ "10.10.0.4/32" ];
        persistentKeepalive = 25;
      }
    ];
  };

  security.sudo.wheelNeedsPassword = false;
  services.openssh.settings.X11Forwarding = true;

  time.timeZone = "America/Los_Angeles";
  console = {
    font = "ter-i24b";
    packages = with pkgs; [ terminus_font ];
    earlySetup = true;
  };
  nixpkgs.hostPlatform = "aarch64-linux";
}
