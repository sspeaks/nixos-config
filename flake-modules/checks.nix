{
  perSystem = { pkgs, lib, ... }: {
    # Two-path fixture for incomplete-cache rejection on Linux targets. Remove
    # the leaf's NAR and .narinfo to test a missing runtime reference. Unique
    # names and contents prevent public caches from satisfying that reference.
    checks = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      nix-copy-fixture =
        let
          marker = "incomplete-cache-nix-copy-fixture-20260902";

          leaf = pkgs.runCommand "${marker}-leaf" { } ''
            mkdir -p "$out"
            echo "${marker}: leaf payload" > "$out/leaf.txt"
          '';
        in
        pkgs.runCommand "${marker}-top" { } ''
          mkdir -p "$out"
          echo "${marker}: top payload" > "$out/top.txt"
          # A real runtime reference keeps the closure at two paths.
          ln -s ${leaf} "$out/leaf"
        '';
    };
  };
}
