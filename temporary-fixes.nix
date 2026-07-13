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

  # Buildable, isolated verify targets — used both by the `verify` hints below
  # and by the `check-temporary-fixes` devshell command, so they stay in sync.
  # Each is a leaf nixpkgs package whose upstream test failure is exactly what
  # its workaround disables; a clean upstream build ⇒ that fix is obsolete.
  pyCatppuccinAttr = "python3Packages.catppuccin";
  # pogbot's app runs on Python 3.12, and that is the interpreter whose
  # inline-snapshot test suite fails — so verify against 3.12 explicitly, not the
  # default python3 (3.14), which passes and hid this regression once already.
  inlineSnapshotAttr = "python312Packages.inline-snapshot";
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
            (lib.optionalAttrs (python-prev ? catppuccin) {
              catppuccin = notice
                {
                  obsolete = python-prev.catppuccin.version != "2.5.0";
                  what = "python catppuccin doCheck=false";
                  evidence = "heuristic: version is now ${python-prev.catppuccin.version} (workaround written for 2.5.0)";
                  verify = verifyBuild pyCatppuccinAttr;
                }
                (python-prev.catppuccin.overridePythonAttrs (_: {
                  doCheck = false;
                }));
            })
            // (lib.optionalAttrs (python-prev ? inline-snapshot) {
              inline-snapshot = notice
                {
                  obsolete = python-prev.inline-snapshot.version != "0.32.5";
                  what = "python inline-snapshot doCheck=false";
                  evidence = "heuristic: version is now ${python-prev.inline-snapshot.version} (workaround written for 0.32.5)";
                  verify = verifyBuild inlineSnapshotAttr;
                }
                (python-prev.inline-snapshot.overridePythonAttrs (_: {
                  doCheck = false;
                }));
            })
          )
        ];

        # Temporary workaround for Python 3.14 argparse incompatibility in
        # catppuccin-gtk's build script: `BooleanOptionalAction` no longer accepts
        # a `type=` kwarg, so drop the `type=bool,` lines. Mirrors nixpkgs master
        # 894acc94f (`catppuccin-gtk: fix build with python314+`). `--replace-warn`
        # (not `--replace-fail`) so this no-ops cleanly once the upstream patch
        # removes those lines. Detection is precise: fires once upstream carries a
        # python-3.14 patch (or bumps past 1.0.3).
        catppuccin-gtk =
          let
            hasUpstreamPy314Patch = builtins.any
              (p: lib.hasInfix "python-3.14" (baseNameOf (toString p)))
              (prev.catppuccin-gtk.patches or [ ]);
          in
          notice
            {
              obsolete = prev.catppuccin-gtk.version != "1.0.3" || hasUpstreamPy314Patch;
              # `precise` only when the upstream patch is actually present (that
              # is definitive); a bare version bump is a heuristic nudge.
              precise = hasUpstreamPy314Patch;
              what = "catppuccin-gtk python3.14 type=bool patch";
              evidence = "version=${prev.catppuccin-gtk.version}, upstream python-3.14 patch ${if hasUpstreamPy314Patch then "present (definitive)" else "absent"}";
              # No `verify`: building catppuccin-gtk from pure upstream would
              # entangle with the python catppuccin doCheck workaround it depends
              # on, giving a false "still needed".
            }
            (prev.catppuccin-gtk.overrideAttrs (old: {
              postPatch = (old.postPatch or "") + ''
                substituteInPlace sources/build/args.py \
                  --replace-warn "type=bool," ""
              '';
            }));
      })
  ];

  # No temporary per-host modules currently. The asahi `vm.mmap_rnd_bits = 31`
  # override was removed 2026-07: nixos-apple-silicon#449 ("failures writing 33
  # to /proc/sys/vm/mmap_rnd_bits") is closed, and nixpkgs now derives the value
  # from the kernel's CONFIG_ARCH_MMAP_RND_BITS_MAX (55-nixos-aslr-entropy.conf),
  # which is 31 for the 16K-page Asahi kernel. The override was only added while
  # the flake's nixpkgs predated that auto-detection. Confirm on the next asahi
  # boot: `cat /proc/sys/vm/mmap_rnd_bits` == 31 and no sysctl "Invalid argument"
  # errors; if wrong, restore `boot.kernel.sysctl."vm.mmap_rnd_bits" = 31;` here.
  hostModules = { };

  # Buildable checks for the `check-temporary-fixes` devshell command. Building
  # each isolated upstream package (no overlay) tests whether the disabled test
  # now passes; a clean build ⇒ that workaround is obsolete.
  verifyTargets = [
    { what = "python catppuccin doCheck=false"; attr = pyCatppuccinAttr; }
    { what = "python inline-snapshot doCheck=false"; attr = inlineSnapshotAttr; }
  ];

  # Workarounds with no isolated build test; reported for manual follow-up.
  manualChecks = [
    {
      what = "catppuccin-gtk python3.14 type=bool patch";
      note = "precise auto-detection via upstream patch presence (watch eval warnings); no isolated build test because it depends on the python catppuccin workaround.";
    }
  ];
}
