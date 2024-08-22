[
  (final: prev: {
    waagent = prev.waagent.overrideAttrs (f: p: {
      runtimeDeps = [ prev.pkgs.which prev.pkgs.python3 prev.pkgs.gawk prev.pkgs.openssl prev.pkgs.gnupg prev.pkgs.lsof ];
      fixupPhase = ''
        mkdir -p $out/bin/
        WAAGENT=$(find $out -name waagent | grep sbin)
        cp $WAAGENT $out/bin/waagent
        wrapProgram "$out/bin/waagent" \
           --prefix PYTHONPATH : $PYTHONPATH \
           --prefix PATH : "${prev.lib.makeBinPath f.runtimeDeps}" \
           --set NIX_LD_LIBRARY_PATH ${prev.lib.makeLibraryPath  [prev.stdenv.cc.cc ]} \
           --set NIX_LD ${builtins.readFile "${prev.stdenv.cc}/nix-support/dynamic-linker"}
        patchShebangs --build "$out/bin/"
      '';
    });
  })
  (final: prev:
      import ./packages { pkgs = final; }
  )
]
