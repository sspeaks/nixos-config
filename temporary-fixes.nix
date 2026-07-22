let
  # Each temporary workaround below is paired with a best-effort obsolescence
  # check that fires when the upstream issue looks resolved, so these don't
  # silently linger. `breakOnObsolete` turns notices into hard (build-breaking)
  # eval errors — but only for `precise` checks; heuristic checks always stay
  # warnings so a routine version/input bump can't block evaluation.
  breakOnObsolete = false;

  # verifyBuild <attr>: a command (run from the repo root) that builds <attr>
  # from the flake's own locked nixpkgs with NO temporary-fixes overlay.
  # `--inputs-from .` reuses the locked nixpkgs, so there's no flake.lock/jq
  # parsing. A clean build ⇒ obsolete. A failure is INCONCLUSIVE: confirm it
  # reproduces the *original* failure (e.g. the disabled test), not an unrelated
  # dependency/platform issue. For a non-current arch, prefix the attr with
  # `legacyPackages.<system>.` (needs that arch's builder/emulation).
  verifyBuild = attr:
    ''nix build -L --no-link --inputs-from . "nixpkgs#${attr}"'';

  # mkNotice lib { obsolete, what, evidence, verify ? null, precise ? false } <value>:
  #   returns <value> unchanged, but at eval time warns (or throws, when
  #   breakOnObsolete AND precise) if `obsolete`. Pass `verify` (a command) when
  #   detection is only heuristic so the reader can settle it for sure.
  mkNotice = lib: { obsolete, what, evidence, verify ? null, precise ? false }:
    let
      msg = "temporary-fixes.nix: '${what}' may be obsolete — ${evidence}."
        + lib.optionalString (verify != null)
        "\n  Confirm before removing by running (from the repo root):\n    ${verify}";
    in
    (if breakOnObsolete && precise then lib.throwIf else lib.warnIf) obsolete msg;

  inlineSnapshotFix = {
    what = "python inline-snapshot doCheck=false";
    # pogbot uses Python 3.12; the default Python 3.14 package already passes.
    attr = "python312Packages.inline-snapshot";
  };

  # Package values to force during `nix flake check`, so their lazy notices are
  # emitted without building the packages.
  noticeTargets = [
    inlineSnapshotFix
  ];

  # Isolated upstream builds used by the `check-temporary-fixes` command.
  verifyTargets = noticeTargets;
  manualChecks = [ ];
in
{
  overlays = [
    (final: prev:
      let
        inherit (prev) lib;
        notice = mkNotice lib;
      in
      {
        # Temporary upstream test-suite workarounds so affected host closures keep
        # building until nixpkgs's test suites pass. `pythonPackagesExtensions`
        # applies across ALL interpreters, so these cover every Python version a
        # host may pull the package in under (catppuccin via python3/3.14 for
        # catppuccin-gtk on asahi; inline-snapshot via python3.12 for pogbot's
        # fastapi stack). Detection is heuristic (whether the disabled tests now
        # pass isn't knowable at eval time), so we re-flag on version change and
        # hand over a `verify` command that rebuilds with upstream's test suite.
        pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
          (_: python-prev:
            (lib.optionalAttrs (python-prev ? inline-snapshot) {
              inline-snapshot = notice
                {
                  obsolete = python-prev.inline-snapshot.version != "0.32.5";
                  what = inlineSnapshotFix.what;
                  evidence = "heuristic: version is now ${python-prev.inline-snapshot.version} (workaround written for 0.32.5)";
                  verify = verifyBuild inlineSnapshotFix.attr;
                }
                (python-prev.inline-snapshot.overridePythonAttrs (_: {
                  doCheck = false;
                }));
            })
          )
        ];
      })
  ];

  hostModules = { };

  inherit noticeTargets verifyTargets manualChecks;
}
