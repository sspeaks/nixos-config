{ config, lib, pkgs, ... }:

let
  cfg = config.services.resticOffsite;
in
{
  # Verify a restore before retiring a host; repository checks alone do not
  # establish that its data can be recovered.
  options.services.resticOffsite = {
    enable = lib.mkEnableOption "offsite restic backup to Azure Cool Blob";

    container = lib.mkOption {
      type = lib.types.str;
      description = "Azure blob container name; becomes azure:<container>:/restic.";
    };

    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Filesystem paths to back up, in addition to the dump staging dir.";
    };

    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Exclude patterns. Derived/regenerable data belongs here.";
    };

    postgresDatabases = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Databases to pg_dump (custom format) before each backup.";
    };

    sqliteDatabases = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Attrset of name -> live SQLite path. Backed up with the `.backup`
        command rather than a file copy, so a WAL-mode database is captured
        consistently instead of being torn mid-transaction.
      '';
    };

    stagingDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/backup/offsite";
      description = "Staging directory for database dumps; included in paths.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.restic.backups =
      let
        common = {
          repository = "azure:${cfg.container}:/restic";
          passwordFile = config.sops.secrets.restic-password.path;
          environmentFile = config.sops.secrets.restic-azure-environment.path;
        };

        # Publish dumps atomically so a failure cannot replace a complete backup.
        pgDumps = lib.concatMapStringsSep "\n"
          (db: ''
            ${pkgs.util-linux}/bin/runuser -u postgres -- \
              ${config.services.postgresql.package}/bin/pg_dump \
              --format=custom --no-password \
              --file=${cfg.stagingDir}/postgres/${db}.dump.new ${db}
            ${pkgs.coreutils}/bin/mv ${cfg.stagingDir}/postgres/${db}.dump.new \
              ${cfg.stagingDir}/postgres/${db}.dump
          '')
          cfg.postgresDatabases;

        sqliteDumps = lib.concatStringsSep "\n"
          (lib.mapAttrsToList
            (name: live: ''
              ${pkgs.sqlite}/bin/sqlite3 ${live} ".backup '${cfg.stagingDir}/sqlite/${name}.db.new'"
              ${pkgs.coreutils}/bin/mv ${cfg.stagingDir}/sqlite/${name}.db.new \
                ${cfg.stagingDir}/sqlite/${name}.db
            '')
            cfg.sqliteDatabases);

        newFiles =
          (map (db: "${cfg.stagingDir}/postgres/${db}.dump.new") cfg.postgresDatabases)
          ++ (lib.mapAttrsToList (name: _: "${cfg.stagingDir}/sqlite/${name}.db.new") cfg.sqliteDatabases);

        rmNew = lib.optionalString (newFiles != [ ])
          "${pkgs.coreutils}/bin/rm -f ${lib.concatStringsSep " " newFiles}";
      in
      {
        offsite = common // {
          initialize = true;
          paths = cfg.paths ++ [ cfg.stagingDir ];
          extraBackupArgs = map (p: "--exclude=${p}") cfg.exclude;

          # Abort on dump failure rather than upload stale dumps as current.
          # Mode 0711 lets postgres traverse the root-owned staging directory
          # without listing it; each database subdirectory remains private.
          backupPrepareCommand = ''
            set -euo pipefail
            ${pkgs.coreutils}/bin/install -d -m 0711 ${builtins.dirOf cfg.stagingDir}
            ${pkgs.coreutils}/bin/install -d -m 0711 ${cfg.stagingDir}
            ${pkgs.coreutils}/bin/install -d -m 0700 ${cfg.stagingDir}/sqlite
            ${pkgs.coreutils}/bin/install -d -o postgres -g postgres -m 0700 ${cfg.stagingDir}/postgres
            ${rmNew}
            ${pgDumps}
            ${sqliteDumps}
          '';

          backupCleanupCommand = rmNew;

          timerConfig = { OnCalendar = "daily"; Persistent = true; };
        };

        # Separate quarterly pruning from daily backups to limit pack rewrites
        # and Azure Cool's 30-day early-deletion charges. The 35-day retention
        # also assumes no Azure lifecycle policy deletes blobs independently.
        offsite-prune = common // {
          paths = [ ];
          pruneOpts = [ "--keep-within 35d" "--keep-weekly 12" "--keep-monthly 12" ];
          timerConfig = { OnCalendar = "*-01,04,07,10-01 03:00:00"; Persistent = true; };
        };
      };
  };
}
