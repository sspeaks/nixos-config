#! /usr/bin/env nix-shell
#! nix-shell -i bash -p sops ssh-to-age
SOPS_AGE_KEY="$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key)" sops updatekeys secrets.yaml