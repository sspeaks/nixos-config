#!/usr/bin/env bash
set -euo pipefail

if [ -z "${_SOPS_WRAPPED:-}" ]; then
  export _SOPS_WRAPPED=1
  exec nix shell nixpkgs#sops nixpkgs#ssh-to-age --command bash "$0" "$@"
fi

DEFAULT_SECRETS="secrets.yaml"
SECRETS_FILE="${1:-$DEFAULT_SECRETS}"

SOPS_AGE_KEY="$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key)" sops -r -i "$SECRETS_FILE"

