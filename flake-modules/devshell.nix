let
  temporaryFixes = import ../temporary-fixes.nix;
  verifyTargets = temporaryFixes.verifyTargets or [ ];
  manualChecks = temporaryFixes.manualChecks or [ ];
in
{
  perSystem = { pkgs, config, lib, ... }:
    let
      # Generated from temporary-fixes.nix's exported check lists, so it stays in
      # sync as workarounds are added/removed.
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
    in
    {
      devshells.default = {
        name = "nixos-config";
        packages = with pkgs; [ sops age ssh-to-age nix-output-monitor ];
        commands = [
          { name = "fmt"; help = "Format the tree"; command = "nix fmt"; }
          { name = "check"; help = "Run flake checks"; command = "nix flake check"; }
          {
            name = "check-temporary-fixes";
            help = "Test whether temporary-fixes.nix workarounds are still needed upstream";
            command = checkTemporaryFixes;
          }
        ];
        devshell.startup.pre-commit-install.text = config.pre-commit.installationScript;
      };
    };
}
