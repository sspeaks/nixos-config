#!/usr/bin/env bash
set -euo pipefail

# One-time remediation for the proxy devops UID move (1001 -> 2001).
#
# hosts/proxy/edge.nix pinned devops to uid 1001, which collided with the
# auto-allocated sspeaks account (serial-rescue had already taken 1000).  Moving
# devops out of the auto-allocation range fixes the collision, but NixOS never
# rewrites ownership of existing files, so every path devops owns still carries
# the old uid.  Left alone those files become sspeaks-owned, because sspeaks is
# the remaining holder of 1001.
#
# Ownership must be repaired by path, never by uid: while both accounts share
# 1001 a uid-based search cannot tell devops' files from sspeaks' files, and
# would hand /home/sspeaks to devops.
#
# Run this after the uid=2001 closure is active on the host.  It is idempotent.

readonly TARGET="${PROXY_TARGET:-20.83.103.87}"
readonly SSH_USER="${PROXY_SSH_USER:-sspeaks}"
readonly EXPECTED_UID=2001

# Keep in sync with the webroots attrset and devops home in hosts/proxy/edge.nix.
readonly PATHS=(
  /var/www/sspeaks.net
  /var/www/mycatsonfire.com
  /var/www/chordplay
  /home/devops
)

say() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

command -v ssh >/dev/null || die "missing runtime command: ssh"

printf -v remote_paths '%q ' "${PATHS[@]}"

ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=yes \
  "${SSH_USER}@${TARGET}" \
  "sudo -n /run/current-system/sw/bin/bash -s -- $EXPECTED_UID $remote_paths" \
  <<'REMOTE_FIX'
set -euo pipefail
expected_uid="$1"
shift

devops_uid="$(id -u devops)" || { printf 'no devops account on host\n' >&2; exit 1; }
if [[ "$devops_uid" != "$expected_uid" ]]; then
  printf 'devops is uid %s, expected %s; activate the uid=%s closure first\n' \
    "$devops_uid" "$expected_uid" "$expected_uid" >&2
  exit 1
fi

# The collision is only resolved once one account holds 1001.  Refuse to touch
# anything while two names still share it, since ownership is then ambiguous.
sharing="$(getent passwd | awk -F: -v u="$devops_uid" '$3 == u { print $1 }')"
if [[ "$sharing" != "devops" ]]; then
  printf 'uid %s is still shared by: %s\n' "$devops_uid" "$(tr '\n' ' ' <<< "$sharing")" >&2
  exit 1
fi

changed=0
for path in "$@"; do
  if [[ ! -e "$path" ]]; then
    printf 'skip (absent): %s\n' "$path"
    continue
  fi
  # /home/devops is group devops; the webroots stay group caddy for Caddy reads.
  if [[ "$path" == /home/devops ]]; then group=devops; else group=caddy; fi
  before="$(find "$path" ! -user devops -printf . 2>/dev/null | wc -c)"
  chown -R "devops:$group" "$path"
  printf 'chowned %-32s -> devops:%-6s (%s entries corrected)\n' "$path" "$group" "$before"
  changed=$((changed + before))
done

printf 'total entries corrected: %s\n' "$changed"

printf '=== verification ===\n'
for path in "$@"; do
  [[ -e "$path" ]] || continue
  stray="$(find "$path" ! -user devops -printf '%p ' 2>/dev/null)"
  if [[ -n "$stray" ]]; then
    printf 'FAIL %s still has non-devops entries: %s\n' "$path" "$stray" >&2
    exit 1
  fi
  printf 'OK   %s\n' "$path"
done

# /home/sspeaks must keep uid 1001; a uid-based chown would have taken it.
sspeaks_owned="$(stat -c '%U' /home/sspeaks 2>/dev/null || echo missing)"
printf 'home/sspeaks owner: %s\n' "$sspeaks_owned"
[[ "$sspeaks_owned" == sspeaks ]] || { printf 'FAIL /home/sspeaks owner is not sspeaks\n' >&2; exit 1; }
REMOTE_FIX
