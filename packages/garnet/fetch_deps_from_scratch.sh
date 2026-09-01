#!/bin/bash
set -xe
#sed -i -E 's/(nugetDeps =)[^\n]*/\1\"\";/' default.nix # nugetDeps needs to be empty or the passthru.fetch-deps wont work because the derivation is improper
nix build .#local-garnet.passthru.fetch-deps -o fetch-deps.sh
bash fetch-deps.sh deps.json
rm fetch-deps.sh #script no longer needed
#sed -i -E 's/(nugetDeps =)[^\n]*/\1.\/deps.nix;/' default.nix

