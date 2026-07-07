[
  (final: prev: {
    waagent = prev.waagent.overrideAttrs (f: p: {
      runtimeDeps = [ final.pkgs.which final.pkgs.python3 final.pkgs.gawk final.pkgs.openssl final.pkgs.gnupg final.pkgs.lsof ];
      fixupPhase = ''
        mkdir -p $out/bin/
        WAAGENT=$(find $out -name waagent | grep sbin)
        cp $WAAGENT $out/bin/waagent
        wrapProgram "$out/bin/waagent" \
           --prefix PYTHONPATH : $PYTHONPATH \
           --prefix PATH : "${final.lib.makeBinPath f.runtimeDeps}" \
           --set NIX_LD_LIBRARY_PATH ${final.lib.makeLibraryPath  [final.stdenv.cc.cc ]} \
           --set NIX_LD ${builtins.readFile "${final.stdenv.cc}/nix-support/dynamic-linker"}
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
