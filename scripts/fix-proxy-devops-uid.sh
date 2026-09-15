#!/usr/bin/env bash
set -euo pipefail

# One-time migration of the proxy devops account from uid/gid 1001 to 2001.
#
# hosts/proxy/edge.nix pinned devops to uid 1001, inside the range NixOS
# auto-allocates normal users from. serial-rescue had taken 1000, so sspeaks was
# auto-allocated 1001 as well and both names resolved to the same uid.
#
# Declaring uid 2001 is not sufficient on a host that already has the account:
# update-users-groups.pl refuses to renumber existing users and only warns,
#
#   warning: not applying UID change of user 'devops' (1001 -> 2001)
#
# so the running host keeps the collision until the account is renumbered here.
# NixOS also never rewrites ownership of existing files, and once devops leaves
# 1001 every file it owns would otherwise resolve to sspeaks, the remaining
# holder of that uid.
#
# Ownership is repaired by path, never by uid: while both accounts share 1001 a
# uid-based search cannot tell devops' files from sspeaks' files and would hand
# /home/sspeaks to devops. Re-run this script freely; it is idempotent.
#
# Run a normal `update-fleet --only proxy` afterwards so activation completes
# and rewrites /var/lib/nixos/uid-map.

readonly TARGET="${PROXY_TARGET:-20.83.103.87}"
readonly SSH_USER="${PROXY_SSH_USER:-sspeaks}"
readonly OLD_ID=1001
readonly NEW_ID=2001

# Keep in sync with the webroots attrset and devops home in hosts/proxy/edge.nix.
readonly WEBROOTS=(
  /var/www/sspeaks.net
  /var/www/mycatsonfire.com
  /var/www/chordplay
)

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

command -v ssh >/dev/null || die "missing runtime command: ssh"

printf -v remote_args '%q ' "$OLD_ID" "$NEW_ID" "${WEBROOTS[@]}"

ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=yes \
  "${SSH_USER}@${TARGET}" \
  "sudo -n /run/current-system/sw/bin/bash -s -- $remote_args" \
  <<'REMOTE_FIX'
set -euo pipefail
old_id="$1" new_id="$2"
shift 2
webroots=("$@")
home=/home/devops

getent passwd devops >/dev/null || { printf 'no devops account on host\n' >&2; exit 1; }
cur_uid="$(id -u devops)"
cur_gid="$(getent group devops | cut -d: -f3)"

case "$cur_uid" in
  "$new_id") printf 'devops already uid %s; re-asserting ownership only\n' "$new_id" ;;
  "$old_id")
    # A concurrent publish would leave half its upload on the old uid; the
    # recursive chown below repairs that, but refuse if devops holds a session.
    if loginctl list-sessions --no-legend 2>/dev/null | awk '{print $3}' | grep -qx devops; then
      printf 'devops has an active login session; retry when it is idle\n' >&2
      exit 1
    fi
    printf 'renumbering devops %s -> %s\n' "$old_id" "$new_id"
    # groupmod first: usermod sets the passwd gid field from the existing group.
    if [[ "$cur_gid" != "$new_id" ]]; then
      groupmod -g "$new_id" devops
    fi
    # usermod refuses while any process still runs as the old uid, and the
    # collision guarantees one does: our own SSH session is sspeaks on 1001.
    # That check cannot be satisfied here, so fall back to rewriting the passwd
    # entry the same way NixOS' own update-users-groups.pl does, and validate
    # the result before installing it.
    if ! usermod -u "$new_id" devops 2>/dev/null; then
      printf 'usermod blocked by a process on the shared uid; rewriting passwd\n'
      backup="/etc/passwd.bak-$(date +%Y%m%d%H%M%S)"
      cp -a /etc/passwd "$backup"
      staged="$(mktemp /etc/passwd.XXXXXX)"
      awk -F: -v OFS=: -v new="$new_id" \
        '$1 == "devops" { $3 = new } { print }' /etc/passwd > "$staged"

      before_lines="$(wc -l < /etc/passwd)"
      after_lines="$(wc -l < "$staged")"
      devops_line="$(awk -F: '$1 == "devops"' "$staged" | wc -l)"
      devops_uid="$(awk -F: '$1 == "devops" { print $3 }' "$staged")"
      sspeaks_uid="$(awk -F: '$1 == "sspeaks" { print $3 }' "$staged")"
      if [[ "$before_lines" != "$after_lines" || "$devops_line" != 1 ||
            "$devops_uid" != "$new_id" || "$sspeaks_uid" != "$old_id" ]]; then
        rm -f "$staged"
        printf 'refusing to install a passwd file that failed validation\n' >&2
        exit 1
      fi
      chown root:root "$staged"
      chmod 0644 "$staged"
      mv "$staged" /etc/passwd
      printf 'passwd rewritten (backup at %s)\n' "$backup"
    fi
    ;;
  *) printf 'devops is uid %s, expected %s or %s; refusing to guess\n' \
       "$cur_uid" "$old_id" "$new_id" >&2; exit 1 ;;
esac

# The collision is only resolved once a single name holds the old uid.
sharing="$(getent passwd | awk -F: -v u="$old_id" '$3 == u { print $1 }' | tr '\n' ' ')"
[[ "$sharing" == "sspeaks " ]] || {
  printf 'uid %s should belong to sspeaks alone, got: %s\n' "$old_id" "$sharing" >&2
  exit 1
}

corrected=0
for path in "${webroots[@]}" "$home"; do
  if [[ ! -e "$path" ]]; then
    printf 'skip (absent): %s\n' "$path"
    continue
  fi
  # Webroots stay group caddy so Caddy keeps reading them; the home is its own.
  if [[ "$path" == "$home" ]]; then group=devops; else group=caddy; fi
  stale="$(find "$path" \( ! -user devops -o ! -group "$group" \) -printf . | wc -c)"
  chown -R "devops:$group" "$path"
  printf 'chowned %-30s -> devops:%-6s (%s corrected)\n' "$path" "$group" "$stale"
  corrected=$((corrected + stale))
done
printf 'total entries corrected: %s\n' "$corrected"

printf '=== verification ===\n'
for path in "${webroots[@]}" "$home"; do
  [[ -e "$path" ]] || continue
  if [[ "$path" == "$home" ]]; then group=devops; else group=caddy; fi
  stray="$(find "$path" \( ! -user devops -o ! -group "$group" \) -printf '%p ' )"
  [[ -z "$stray" ]] || { printf 'FAIL %s still stray: %s\n' "$path" "$stray" >&2; exit 1; }
  printf 'OK   %s (devops:%s)\n' "$path" "$group"
done

# sspeaks must keep 1001 and its home; a uid-based chown would have taken it.
owner="$(stat -c '%U' /home/sspeaks 2>/dev/null || echo missing)"
[[ "$owner" == sspeaks ]] || { printf 'FAIL /home/sspeaks owner is %s\n' "$owner" >&2; exit 1; }
printf 'OK   /home/sspeaks (sspeaks)\n'
printf 'devops now uid %s gid %s\n' "$(id -u devops)" "$(getent group devops | cut -d: -f3)"
REMOTE_FIX
