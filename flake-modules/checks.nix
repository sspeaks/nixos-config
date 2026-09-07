{ self, ... }:
{
  perSystem = { pkgs, lib, ... }: {
    # P1.1 supply-chain fixture.
    #
    # Purpose: prove that target-side `nix copy --from <cache>` fails CLOSED when
    # the cache is missing a referenced path, and that it fails *before* anything
    # is activated. Proving that needs a closure with a known, deliberately
    # broken reference, which is what this fixture is.
    #
    # Two properties are load-bearing:
    #
    #   1. Exactly two store paths (top -> leaf). Small enough that "delete the
    #      leaf's NAR and .narinfo" is an unambiguous way to build an incomplete
    #      cache, with no ambiguity about which path went missing.
    #
    #   2. Unique content. The marker is baked into both derivation names and
    #      their contents, so these paths exist in no public cache. If they were
    #      substitutable from cache.nixos.org the target could quietly satisfy
    #      the "missing" reference from elsewhere and the test would pass while
    #      proving nothing.
    #
    # Linux-only: the fixture exists to be copied to a Linux target, and the
    # controller is aarch64-darwin.
    checks = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      pi4-identity =
        let
          hosts = self.nixosConfigurations;
          pi = hosts.nixpi4-services.config;
        in
        assert lib.assertMsg (!(hosts ? nixpi4-bare) && !(hosts ? nixpi4))
          "Neither the old bare name nor the hardware-only name should remain as an ambiguous alias.";
        assert lib.assertMsg (pi.networking.hostName == "nixpi4-services")
          "The home Pi 4 configuration and hostname must both describe the services role.";
        assert lib.assertMsg (hosts ? nixpi && hosts ? vm && hosts ? asahi)
          "The owner-retained nixpi, vm and asahi configurations must remain available.";
        assert lib.assertMsg (hosts.nixpi.config.networking.hostName == "nixpi")
          "The travel-router variant remains a distinct configuration.";
        assert lib.assertMsg (pi.networking.wireguard.interfaces.wg-edge.ips == [ "10.10.0.3/32" ])
          "Renaming the Pi must not move its workload overlay address.";
        pkgs.runCommandLocal "pi4-identity" { } ''
          touch "$out"
        '';

      nix-copy-fixture =
        let
          marker = "p1-1-nix-copy-fixture-20260902";

          leaf = pkgs.runCommand "${marker}-leaf" { } ''
            mkdir -p "$out"
            echo "${marker}: leaf payload" > "$out/leaf.txt"
          '';
        in
        pkgs.runCommand "${marker}-top" { } ''
          mkdir -p "$out"
          echo "${marker}: top payload" > "$out/top.txt"
          # The symlink embeds the leaf's store path in the output, which is what
          # registers it as a runtime reference. Without a real reference the
          # closure would be one path and the fixture would prove nothing.
          ln -s ${leaf} "$out/leaf"
        '';
    };
  };
}
