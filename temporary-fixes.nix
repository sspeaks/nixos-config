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
  #   breakOnObsolete && precise) if `obsolete`. Pass `verify` (a command) when
  #   detection is only heuristic so the reader can settle it for sure.
  mkNotice = lib: { obsolete, what, evidence, verify ? null, precise ? false }:
    let
      msg = "temporary-fixes.nix: '${what}' may be obsolete — ${evidence}."
        + lib.optionalString (verify != null)
        "\n  Confirm before removing by running (from the repo root):\n    ${verify}";
    in
    (if breakOnObsolete && precise then lib.throwIf else lib.warnIf) obsolete msg;

  # Package values to force during `nix flake check`, so their lazy notices are
  # emitted without building the packages.
  noticeTargets = [ ];

  # Isolated upstream builds used by the `check-temporary-fixes` command.
  verifyTargets = noticeTargets;
  manualChecks = [ ];
in
{
  overlays = [
    (_: _: { })
  ];

  hostModules = { };

  inherit noticeTargets verifyTargets manualChecks;
}
