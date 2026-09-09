{ config, lib, pkgs, ... }:

let
  cfg = config.services.resticOffsite;
in
{
  # P1.2 offsite backup to Azure Cool Blob.
  #
  # The point of this module is the RESTORE, not the backup. Old Azure VMs only
  # become deletable once irreplaceable data has been demonstrably restored --
  # `restic check` alone is explicitly not sufficient, because it verifies
  # repository structure rather than that the bytes come back.
  #
  # Two design constraints come from the migration plan:
  #
  #   * Backup and prune are SEPARATE jobs on different schedules. Cool-tier
  #     blobs have a 30-day minimum retention; pruning rewrites packs, so a
  #     frequent prune would repeatedly delete under-age objects and incur
  #     early-deletion charges. Daily backup + quarterly prune keeps rewritten
  #     packs alive well past the minimum.
  #
  #   * Database dumps are fail-closed and atomic. Each dump writes `.new` and
  #     is renamed into place only on success, so a failed dump can never
  #     silently publish a truncated file as if it were a good backup. The
  #     staging directory is itself inside `paths`.
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

          # set -euo pipefail matters: without it a failed pg_dump would be
          # ignored and the previous good .dump would be re-uploaded as though
          # it were current.
          #
          # The staging ROOT is 0711, not 0700. pg_dump runs as `postgres` via
          # runuser and must traverse this directory to reach its own 0700
          # subdirectory; a 0700 root-owned parent denies that traversal and the
          # dump fails with EACCES. 0711 grants traverse without list, so the
          # directory's contents stay unenumerable while the child directories
          # keep their own 0700 ownership boundaries.
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

        # Quarterly. `--keep-within 35d` is the application-side half of the
        # 30-day Cool-minimum proof; the other half is the absent Azure
        # lifecycle policy. Verified by reading back the deployed unit, not the
        # source text.
        offsite-prune = common // {
          paths = [ ];
          pruneOpts = [ "--keep-within 35d" "--keep-weekly 12" "--keep-monthly 12" ];
          timerConfig = { OnCalendar = "*-01,04,07,10-01 03:00:00"; Persistent = true; };
        };
      };
  };
}
