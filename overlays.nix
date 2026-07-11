[
  (final: prev: {
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

    waagent = prev.waagent.overrideAttrs (f: p: {
      runtimeDeps = [ prev.which prev.python3 prev.gawk prev.openssl prev.gnupg prev.lsof ];
      fixupPhase = ''
        mkdir -p $out/bin/
        WAAGENT=$(find $out -name waagent | grep sbin)
        cp $WAAGENT $out/bin/waagent
        wrapProgram "$out/bin/waagent" \
           --prefix PYTHONPATH : $PYTHONPATH \
           --prefix PATH : "${prev.lib.makeBinPath f.runtimeDeps}" \
           --set NIX_LD_LIBRARY_PATH ${prev.lib.makeLibraryPath [ prev.stdenv.cc.cc ]} \
           --set NIX_LD ${prev.stdenv.cc.bintools.dynamicLinker}
        patchShebangs --build "$out/bin/"
      '';
    });
  })

  (
    (final: prev:
      import ./packages { pkgs = final; system = prev.stdenv.hostPlatform.system; }
    )
  )
]
