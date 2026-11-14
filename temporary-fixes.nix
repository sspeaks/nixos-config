let
  # Precise obsolescence checks may fail evaluation; heuristics always warn
  # so routine input updates are not blocked by uncertain matches.
  breakOnObsolete = false;

  # Build from the repo root against locked nixpkgs without this overlay.
  # A clean build makes the workaround obsolete; failures must reproduce the
  # original issue. For another architecture, use legacyPackages.<system>.<attr>
  # with a matching builder or emulation.
  verifyBuild = attr:
    ''nix build -L --no-link --inputs-from . "nixpkgs#${attr}"'';

  # Heuristic notices should supply a verification command.
  mkNotice = lib: { obsolete, what, evidence, verify ? null, precise ? false }:
    let
      msg = "temporary-fixes.nix: '${what}' may be obsolete — ${evidence}."
        + lib.optionalString (verify != null)
        "\n  Confirm before removing by running (from the repo root):\n    ${verify}";
    in
    (if breakOnObsolete && precise then lib.throwIf else lib.warnIf) obsolete msg;

  # Force these packages' notices during flake checks without building them.
  noticeTargets = [ ];

  # Isolated upstream builds used by the `check-temporary-fixes` command.
  verifyTargets = noticeTargets;
  manualChecks = [ ];
in
{
  overlays = [
    (_: _: { })
  ];

  hostModules =
    let
      # Temporary workaround: glibc 2.44's arm64 UAPI headers use `__u128`,
      # which the kernel's private tools/include/linux/types.h lacks, so
      # resolve_btfids fails to build. nixpkgs only patches its own mainline
      # kernels; the vendor kernels need it too. Drop once upstream
      # 10a47fb67340 is in each vendor kernel (the patch will then fail to apply).
      # nixpi's kernel ignores boot.kernelPatches; see hosts/nixpi/hardware-config.nix.
      tools128bitTypes = { pkgs, ... }: {
        boot.kernelPatches = [ pkgs.kernelPatches.tools_128bit_types ];
      };
    in
    {
      asahi = tools128bitTypes;
      nixpi5 = tools128bitTypes;
    };

  inherit noticeTargets verifyTargets manualChecks;
}
