let
  temporaryFixes = import ../temporary-fixes.nix;
  noticeTargets = temporaryFixes.noticeTargets or [ ];
  verifyTargets = temporaryFixes.verifyTargets or [ ];
  manualChecks = temporaryFixes.manualChecks or [ ];
in
{
  perSystem = { pkgs, config, lib, ... }:
    let
      checkTemporaryFixes = ''
        set -uo pipefail
        root="''${PRJ_ROOT:-.}"
        echo "Checking whether temporary-fixes.nix workarounds are still needed upstream..."
        echo "(building each isolated upstream package from the flake's locked nixpkgs; a clean build => obsolete)"
        echo
      ''
      + lib.concatMapStrings
        (t: ''
          echo "== ${t.what}  (nixpkgs#${t.attr})"
          if nix build -L --no-link --inputs-from "$root" "nixpkgs#${t.attr}"; then
            echo "   OBSOLETE: builds clean upstream -> you can likely drop this workaround."
          else
            echo "   STILL NEEDED: upstream still fails (confirm it is the original failure, not an unrelated dep)."
          fi
          echo
        '')
        verifyTargets
      + lib.optionalString (manualChecks != [ ]) (''
        echo "Manual checks (no automated build test):"
      ''
      + lib.concatMapStrings
        (m: ''
          echo "   - ${m.what}: ${m.note}"
        '')
        manualChecks);

      checkTemporaryFixesApp = pkgs.writeShellApplication {
        name = "check-temporary-fixes";
        text = checkTemporaryFixes;
      };

      # Force the wrapped package values far enough to emit their lazy notices,
      # but only retain plain version strings so the check has no package build
      # dependencies.
      temporaryFixNoticeState = lib.concatMapStringsSep "\n"
        (target:
          let
            package = lib.attrByPath
              (lib.splitString "." target.attr)
              (throw "temporary-fixes.nix notice target '${target.attr}' does not exist")
              pkgs;
          in
          "${target.what}: ${package.version}")
        noticeTargets;
    in
    {
      apps.check-temporary-fixes = {
        type = "app";
        program = lib.getExe checkTemporaryFixesApp;
        meta.description = "Test whether temporary-fixes.nix workarounds are still needed upstream";
      };

      checks.temporary-fixes = pkgs.runCommandLocal "temporary-fixes-notices"
        { noticeState = temporaryFixNoticeState; }
        ''
          printf '%s\n' "$noticeState" > "$out"
        '';

      devshells.default = {
        name = "nixos-config";
        packages = with pkgs; [ sops age ssh-to-age nix-output-monitor ];
        commands = [
          { name = "fmt"; help = "Format the tree"; command = "nix fmt"; }
          {
            name = "check";
            help = "Run flake checks";
            command = ''exec nix flake check --no-eval-cache "''${PRJ_ROOT:-.}"'';
          }
          {
            name = "check-temporary-fixes";
            help = "Test whether temporary-fixes.nix workarounds are still needed upstream";
            command = ''exec nix run "''${PRJ_ROOT:-.}#check-temporary-fixes"'';
          }
        ];
        devshell.startup.pre-commit-install.text = config.pre-commit.installationScript;
      };
    };
}
