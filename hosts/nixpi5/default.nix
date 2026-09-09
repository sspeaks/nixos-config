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
    ../../modules/restic-offsite.nix
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

  # ------------------------------------------------------------- backups ---
  # Until now this host had NO backups of any kind: no restic, no borg, and
  # restic-offsite was enabled on exactly one machine in the estate,
  # hosts/vid-stream. That is the wrong host to be the only one -- it is the one
  # slated to move home and then be deleted -- and it left the Authentik
  # database unprotected, which is the SSO that gates auth.sspeaks.net,
  # home-assistant.sspeaks.net and streams.sspeaks.net through oauth2-proxy.
  #
  # The `nixpi5` blob container already existed; it was created in P1.2
  # alongside the others and never used.
  #
  # The restic password here is deliberately NOT the same as vid-stream's, so
  # that compromising this host cannot decrypt vid-stream's repository. The
  # Azure environment file is shared, because it is the same storage account.
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

    # Authentik keeps its real state in postgres, so it is dumped rather than
    # copied: /var/lib/authentik is 0 bytes. /var/lib/postgresql is deliberately
    # NOT in `paths` -- copying a live cluster directory yields a torn,
    # unrestorable snapshot, which is exactly what pg_dump avoids.
    postgresDatabases = [ "authentik" ];

    # Home Assistant's recorder database. `.backup` is required rather than a
    # file copy: Home Assistant runs SQLite in WAL mode, so a plain copy can
    # miss the -wal contents and restore torn state. No -wal sidecar happened
    # to be present when this was written, which only means it had just been
    # checkpointed; it is not a reason to copy the file directly.
    sqliteDatabases = {
      home-assistant = "/var/lib/hass/home-assistant_v2.db";
    };

    paths = [
      # Automations, blueprints, custom components, the device registry, and
      # the .storage tree that holds every entity's configuration.
      "/var/lib/hass"
      # systemd DynamicUser state. Holds authentik's media and certificates,
      # which are NOT in the database, plus ntfy-sh.
      "/var/lib/private"
      "/var/lib/snappymail"
      # The Samba passdb and Debian fstab/smb.conf carried across during the
      # P2.2 .106 conversion. Small, and not reproducible if lost.
      "/var/lib/migration-seed"
    ];

    exclude = [
      # Python dependencies and HTTP caches that Home Assistant refetches.
      "/var/lib/hass/deps"
      "/var/lib/hass/.cache"
    ];
  };

  # Deliberately NOT backed up:
  #   /var/lib/garage-monitor  2.0 GB, and the module is currently commented out
  #     of the imports above, so this is stale data from when it last ran. It is
  #     1.2 GB of downloadable ML model-cache plus 849 MB of camera JPEGs -- a
  #     monitoring stream, not irreplaceable state.
  #   /var/lib/docker, /var/lib/containers  image layers, refetchable. The
  #     docker volumes that would matter total 100 KB and snappymail's real
  #     configuration lives in /var/lib/snappymail, which IS included.
  #   /var/lib/rspamd, /var/lib/tor  regenerable service state.

  networking.wireguard.enable = true;
  networking.wireguard.interfaces.wg-edge = {
    ips = [ "10.10.0.2/32" ];
    privateKeyFile = config.sops.secrets.wg-edge-private-key.path;
    peers = [
      {
        publicKey = "gTkLAa4pN+STVJDde9wWI4QDi4AFBn/ArTx6ul/PFAU=";
        endpoint = "40.86.75.95:51820";
        # Only the edge's own overlay address. NOT a LAN prefix: the edge must
        # never be able to route into 192.168.5.0/24, which is what the P1.4
        # narrowing of the old tunnel was about.
        allowedIPs = [ "10.10.0.1/32" ];
        persistentKeepalive = 25;
      }
      {
        # P4.1 replacement edge. Carried alongside the old one deliberately:
        # both edges must be reachable at once so the P4.2 DNS cutover is the
        # only thing that switches, and so it can be reversed without touching
        # the tunnel. The new edge has its own overlay address because
        # WireGuard cannot have two peers sharing allowedIPs.
        publicKey = "Sbm2/JkGPNO9LEsrI2oJSHZNIxoOCsf/2l8jwm6AtHM=";
        endpoint = "20.83.103.87:51820";
        allowedIPs = [ "10.10.0.4/32" ];
        persistentKeepalive = 25;
      }
    ];
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

