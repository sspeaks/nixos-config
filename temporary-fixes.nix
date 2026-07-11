{
  overlays = [
    (final: prev: {
      # Temporary upstream test-suite workarounds so affected host closures keep
      # building until nixpkgs lands fixes for these packages.
      pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
        (_: python-prev:
          (prev.lib.optionalAttrs (python-prev ? catppuccin) {
            catppuccin = python-prev.catppuccin.overridePythonAttrs (_: {
              doCheck = false;
            });
          })
          // (prev.lib.optionalAttrs (python-prev ? inline-snapshot) {
            inline-snapshot = python-prev.inline-snapshot.overridePythonAttrs (_: {
              doCheck = false;
            });
          })
        )
      ];
    })
  ];

  hostModules = {
    asahi = { ... }: {
      # Temporary workaround: Asahi uses 16K pages but nixpkgs still
      # mis-detects page size here (nixos-apple-silicon#449). `31` matches the
      # upstream ARM64_16K_PAGES fix so ASLR keeps the expected mmap entropy.
      # Drop this once nixpkgs#513687 lands in nixos-unstable.
      boot.kernel.sysctl."vm.mmap_rnd_bits" = 31;
    };
  };
}
