#!/bin/bash
set -xe
#sed -i -E 's/(nugetDeps =)[^\n]*/\1\"\";/' default.nix # nugetDeps needs to be empty or the passthru.fetch-deps wont work because the derivation is improper
nix-build -A server.passthru.fetch-deps -o fetch-deps.sh # generates a bash script we need to call to generate the dependencies derivation
bash fetch-deps.sh deps.nix
rm fetch-deps.sh #script no longer needed
#sed -i -E 's/(nugetDeps =)[^\n]*/\1.\/deps.nix;/' default.nix

