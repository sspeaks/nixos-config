{ pkgs, lib, inputs, config, ... }:
let
  sopsFileLocation = {
    format = "yaml";
    sopsFile = ../../secrets/vidbox.yaml;
  };
in
# `vidbox` -- the home Hyper-V VM running the former Azure video workload.
  #
  # ---------------------------------------------------------------------------
  # Bootstrap the account before enabling secrets. The install history matters.
  #
  # A freshly installed host has no sops identity. sops-nix derives its age key
  # from /etc/ssh/ssh_host_ed25519_key, which does not exist until the installer
  # has run, so its public half cannot be in .sops.yaml beforehand and the host
  # cannot decrypt secrets/common.yaml on first boot. The proxy hit exactly this
  # during provisioning and shipped with its rescue account locked for the same
  # reason.
  #
  # Pass one therefore ran WITHOUT ../common/users/sspeaks -- that module declares
  # sops secrets (sspeaks-password with neededForUsers, the github ssh key, three
  # copilot secrets, the OpenAI key) and every one would have failed to decrypt,
  # taking user creation down with it and leaving an unloginable machine. The user
  # was defined inline instead, key-only with a locked password.
  #
  # After installation the host key was scanned, converted with ssh-to-age,
  # added to .sops.yaml under hosts and to the common.yaml rule, and common.yaml
  # was re-encrypted. The inline user was then replaced by the shared module
  # below.
  #
  # `determinate` follows this flake's nixpkgs, so it is NOT in Determinate's
  # own cache. The retired Azure video host also imported it, so CI had already
  # published that exact x86_64 derivation to sspeaks-nix during installation. The
  # installer only ever rebuilt it (wasmtime, via rustc) because the live ISO had
  # no access to that cache. The installed system does.
  # ---------------------------------------------------------------------------
{
  imports = [
    ../common/global
    ../common/users/sspeaks
    ../common/users/sspeaks/authorized-keys.nix
    ./hardware-configuration.nix
    ./ai-coaching.nix
    ../../modules/restic-offsite.nix
    inputs.home-manager.nixosModules.home-manager
    inputs.determinate.nixosModules.default
    inputs.large-video-streamer.nixosModules.vidStreamer
    inputs.ai-coaching-dashboard.nixosModules.aiCoaching
  ];

  # ------------------------------------------------------------- secrets ---
  # Carried over from secrets/vid-stream.yaml and re-encrypted to this host's
  # identity. Same values, because this host takes over the same workload and
  # the same OIDC client registration in authentik -- changing them would mean
  # re-registering the application.
  sops.secrets = {
    vid-streamer-login-user = sopsFileLocation // {
      owner = "vid-streamer";
      group = "users";
      mode = "0400";
    };
    vid-streamer-login-pass = sopsFileLocation // {
      owner = "vid-streamer";
      group = "users";
      mode = "0400";
    };
    ai-coaching-oidc-client-secret = sopsFileLocation // {
      owner = "oauth2-proxy";
      group = "oauth2-proxy";
      mode = "0400";
    };
    ai-coaching-oauth2-proxy-cookie-secret = sopsFileLocation // {
      owner = "oauth2-proxy";
      group = "oauth2-proxy";
      mode = "0400";
    };
    ai-coaching-postgresql-evidence-password = sopsFileLocation // {
      owner = "root";
      group = "root";
      mode = "0400";
    };
    ai-coaching-proxy-auth-env = sopsFileLocation // { mode = "0400"; };
    ai-coaching-speakr-env = sopsFileLocation // { mode = "0400"; };
    ai-coaching-evidence-api-env = sopsFileLocation // { mode = "0400"; };
    ai-coaching-evidence-worker-env = sopsFileLocation // { mode = "0400"; };
    ai-coaching-extraction-gateway-env = sopsFileLocation // { mode = "0400"; };
    restic-password = sopsFileLocation // {
      owner = "root";
      group = "root";
      mode = "0400";
    };
    restic-azure-environment = sopsFileLocation // {
      owner = "root";
      group = "root";
      mode = "0400";
    };
    wg-edge-private-key = sopsFileLocation // {
      owner = "root";
      mode = "0400";
    };
  };

  # -------------------------------------------------------------- backups ---
  # These jobs replaced the Azure video host's backups before its resource
  # group was deleted. The 41 GB of recordings and ai-coaching data now live
  # on this host, so it must keep backing them up independently.
  #
  # The container is deliberately still "vid-stream", and the restic password
  # was carried across unchanged in secrets/vidbox.yaml, so this host opens the
  # EXISTING repository rather than starting a new one. The backup history from
  # the Azure host therefore continues uninterrupted instead of being orphaned.
  # Note that repository lives in the migration-backup resource group, not in
  # vid-stream's, so deleting that group does not touch it.
  #
  # hls is excluded for the same reason it was never copied: 35 GB of derived
  # segments that vidbox regenerated on its own within minutes of the recordings
  # landing. Backing it up would nearly double the repository for no recovery
  # value.
  services.resticOffsite = {
    enable = true;
    container = "vid-stream";
    paths = [
      "/srv/videos"
      "/var/lib/ai-coaching"
      "/var/lib/vid-streamer"
    ];
    exclude = [
      "/var/lib/vid-streamer/hls"
    ];
    postgresDatabases = [ "evidence" ];
    sqliteDatabases = {
      # WAL-mode databases: `.backup` gives a consistent snapshot; a plain file
      # copy would miss the -wal contents and could restore torn state.
      vid-streamer-app = "/var/lib/vid-streamer/app.db";
      speakr-transcriptions = "/var/lib/ai-coaching/speakr/instance/transcriptions.db";
    };
  };

  # ----------------------------------------------------------- wireguard ---
  # Home hosts DIAL OUT to the edge; the edge listens. That keeps the
  # residential address out of every Azure-side configuration.
  # persistentKeepalive is not optional for an outbound-only
  # tunnel: without it the home NAT mapping expires and the edge can no longer
  # reach back to deliver traffic.
  #
  # 10.10.0.5, because .2 is nixpi5, .3 is nixpi4-bare and .4 is the edge
  # itself. WireGuard cannot have two peers sharing an allowedIPs entry, so
  # every host needs its own.
  networking.wireguard.enable = true;
  networking.wireguard.interfaces.wg-edge = {
    ips = [ "10.10.0.5/32" ];
    privateKeyFile = config.sops.secrets.wg-edge-private-key.path;
    peers = [
      {
        # proxy, the replacement Azure edge
        publicKey = "Sbm2/JkGPNO9LEsrI2oJSHZNIxoOCsf/2l8jwm6AtHM=";
        endpoint = "20.83.103.87:51820";
        # ONLY the edge's own overlay address. Deliberately not a LAN prefix:
        # the edge must never be able to route into 192.168.5.0/24.
        allowedIPs = [ "10.10.0.4/32" ];
        persistentKeepalive = 25;
      }
    ];
  };

  # --------------------------------------------------------- vid-streamer ---
  # Ported from the retired Azure video host. The edge reverse-proxies
  # streams.sspeaks.net to :8080 (aiCoaching's caddy), and vid-streamer serves
  # on :8081, exactly as in Azure.
  systemd.tmpfiles.rules = [
    "z /srv/videos 0750 sspeaks users -"
  ];

  networking.firewall.allowedTCPPorts = [ 8080 8081 ];

  services.vidStreamer = {
    enable = true;
    package = inputs.large-video-streamer.packages.${pkgs.stdenv.hostPlatform.system}.default;
    videoDir = "/srv/videos";
    videoAccessGroup = "users";
    listenAddr = "0.0.0.0:8081";
    openFirewall = true;
    loginUserFile = config.sops.secrets.vid-streamer-login-user.path;
    loginPassFile = config.sops.secrets.vid-streamer-login-pass.path;
  };

  home-manager.useUserPackages = true;
  home-manager.users.sspeaks = { ... }: {
    imports = [ ../../home/sspeaks-bare.nix ];
  };

  # Matches the other servers. wheelNeedsPassword = false is what makes
  # nixos-anywhere and ./deploy able to activate without an interactive prompt.
  security.sudo.wheelNeedsPassword = false;
  programs.nix-ld.enable = true;

  time.timeZone = "America/Los_Angeles";
}
