#! /usr/bin/env nix-shell
#! nix-shell -i bash -p sops ssh-to-age

DEFAULT_SECRETS="secrets.yaml"
SECRETS_FILE="${1:-$DEFAULT_SECRETS}"

SOPS_AGE_KEY="$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key)" sops updatekeys "$SECRETS_FILE"
