#!/bin/bash
set -xe
nix build .#local-garnet.passthru.fetch-deps -o fetch-deps.sh
bash fetch-deps.sh deps.json
rm fetch-deps.sh
