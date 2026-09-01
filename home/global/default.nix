{ lib, pkgs, config, ... }:
{
  imports = [
    ../features/step-ssh
  ];

  nix = {
    package = lib.mkDefault pkgs.nix;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      warn-dirty = false;
    };
  };

  programs = {
    home-manager.enable = true;
    git.enable = true;
  };

  home = {
    username = lib.mkDefault "sspeaks";
    homeDirectory = lib.mkDefault (
      (if pkgs.stdenv.hostPlatform.system == "aarch64-darwin" then "/Users/" else "/home/") +
      "${config.home.username}"
    );
    stateVersion = lib.mkDefault "23.05";
    sessionVariables = {
      SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      SSL_CERT_DIR = "${pkgs.cacert}/etc/ssl/certs";
    };
  };

  # Trim old generations of the per-user profiles only. Reclaiming the store
  # itself is the system GC's job (nix.gc in hosts/common/global); doing it here
  # too just deadlocks on the GC lock and frees nothing. Running daily keeps
  # these roots released well before the weekly system GC runs.
  systemd.user.services.nix-user-profile-trim = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit.Description = "Trim old Nix user profile generations";
    Service = {
      Type = "oneshot";
      ExecStart =
        let
          profiles = [
            "%h/.local/state/nix/profiles/home-manager"
            "%h/.local/state/nix/profiles/profile"
          ];
          trim = p: "${config.nix.package}/bin/nix-env --profile ${p} --delete-generations 14d";
        in
        map (p: "-${trim p}") profiles;
    };
  };
  systemd.user.timers.nix-user-profile-trim = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit.Description = "Trim old Nix user profile generations";
    Timer = {
      OnCalendar = "daily";
      RandomizedDelaySec = "1h";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
