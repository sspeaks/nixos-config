[
  (final: prev: {
    waagent = prev.waagent.overrideAttrs (f: p: {
      runtimeDeps = p.runtimeDeps ++ [ prev.pkgs.which prev.pkgs.python3 ];
      fixupPhase = ''
        mkdir -p $out/bin/
        WAAGENT=$(find $out -name waagent | grep sbin)
        cp $WAAGENT $out/bin/waagent
        wrapProgram "$out/bin/waagent" \
           --prefix PYTHONPATH : $PYTHONPATH \
           --prefix PATH : "${prev.lib.makeBinPath f.runtimeDeps}"
        patchShebangs --build "$out/bin/"
      '';
    });
  })
]

