#!/usr/bin/env bash
set -euo pipefail

readonly CACHIX_URL="https://sspeaks-nix.cachix.org"
readonly CACHIX_KEY="sspeaks-nix.cachix.org-1:Umjs3o8MgvHklkotM8S4XBfTz+zEQCnyr8TFpIC9x+o="
readonly UPSTREAM_URL="https://cache.nixos.org"
readonly UPSTREAM_KEY="cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
readonly GH_REPO="${FLEET_GH_REPO:-sspeaks/nixos-config}"
readonly FLEET=(
  "raspberrytimemachine|192.168.5.106||Time Machine appliance"
  "vidbox|192.168.5.195||video and ai-coaching"
  "nixpi4-bare|192.168.5.16|nixpi4-bare|pogbot and boggle"
  "nixpi5|192.168.5.238||Authentik SSO and home services"
  "proxy|20.83.103.87||public edge"
)

repo="${FLEET_DEFAULT_REPO:-$PWD}"
check_only=false
prefetch_only=false
only_hosts=()
names=() targets=() aliases=() notes=() outcomes=() paths=() ready=()
tmp=""
phase="arguments"
summary_enabled=false
incomplete=false
head_sha=""

say() { printf '%s\n' "$*"; }
die() { printf 'ERROR [%s]: %s\n' "$phase" "$*" >&2; exit 1; }
usage() {
  printf '%s\n' \
    'Usage: ./update-fleet [options]' \
    '  --check          Inspect reachability, cache availability and drift.' \
    '  --only HOST      Select a fleet host (repeatable).' \
    '  --prefetch-only  Populate target stores; do not activate.' \
    '  --repo PATH      Working checkout (does not select the deployed revision).' \
    '  -h, --help       Show help.' \
    '' \
    'Deploys the latest successfully built main commit from CI to all reachable' \
    'fleet hosts. Paths come from CI-published manifests; no flake inputs are' \
    'updated and deployment never builds system closures.' \
    'Activation is persistent (switch); hosts reboot automatically when needed.' \
    '' \
    'GitHub authentication, SSH access, and independently verified host keys must' \
    'be configured. Incomplete or per-host-failed runs exit nonzero.' \
    'Drift alone in --check does not fail. --check does not activate targets.'
}
finish() {
  local status=$? i
  trap - EXIT
  if $summary_enabled; then
    say ""
    say "Host results:"
    for i in "${!names[@]}"; do
      printf '  %-24s %s\n' "${names[$i]}" "${outcomes[$i]}"
    done
  fi
  [[ -z "$tmp" ]] || rm -rf -- "$tmp"
  if $incomplete && (( status == 0 )); then status=1; fi
  exit "$status"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

while (( $# )); do
  case "$1" in
    --check) check_only=true ;;
    --prefetch-only) prefetch_only=true ;;
    --no-update)
      printf 'WARNING: --no-update is deprecated and has no effect; fleet deploys from CI artifacts\n' >&2 ;;
    --auto-merge)
      die "--auto-merge is no longer supported; fleet update is driven by CI artifacts (no PR workflow)" ;;
    --only|--repo)
      (( $# >= 2 )) && [[ -n "$2" && "$2" != -* ]] || die "$1 requires a value"
      if [[ "$1" == --only ]]; then only_hosts+=("$2"); else repo="$2"; fi
      shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
  shift
done
$check_only && $prefetch_only && die "--check and --prefetch-only are mutually exclusive"
contains() {
  local wanted="$1" item
  shift
  for item in "$@"; do [[ "$item" == "$wanted" ]] && return 0; done
  return 1
}
for requested in "${only_hosts[@]}"; do
  found=false
  for entry in "${FLEET[@]}"; do
    [[ "${entry%%|*}" == "$requested" ]] && found=true
  done
  $found || die "unknown fleet host: $requested"
done
for entry in "${FLEET[@]}"; do
  IFS='|' read -r name target alias note <<< "$entry"
  if (( ${#only_hosts[@]} )) && ! contains "$name" "${only_hosts[@]}"; then continue; fi
  names+=("$name"); targets+=("$target"); aliases+=("$alias"); notes+=("$note")
  outcomes+=("not attempted"); paths+=("")
done

phase=preflight
for command in nix git ssh jq gh timeout mktemp rm sleep; do
  command -v "$command" >/dev/null || die "missing runtime command: $command; use the Nix launcher"
done
timeout 30 gh auth status ||
  die "GitHub authentication required; run: gh auth login"
repo="$(cd "$repo" && pwd -P)" || die "cannot enter checkout: $repo"
[[ -f "$repo/flake.nix" ]] || die "checkout has no flake.nix: $repo"
git -C "$repo" rev-parse --is-inside-work-tree >/dev/null || die "not a Git checkout"
cd "$repo"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/update-fleet.XXXXXXXX")" || die "could not create private temporary directory"
summary_enabled=true

fleet_ssh_t() {
  # fleet_ssh_t <timeout_secs> <host_index> [remote_cmd...]
  local t="$1" i="$2"
  shift 2
  local opts=(-o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=yes
    -o ServerAliveInterval=5 -o ServerAliveCountMax=2)
  [[ -z "${aliases[$i]}" ]] || opts+=(-o "HostKeyAlias=${aliases[$i]}")
  timeout "$t" ssh "${opts[@]}" "sspeaks@${targets[$i]}" "$@"
}
fleet_ssh() { fleet_ssh_t 30 "$@"; }

skip() {
  outcomes[$1]="$2"
  incomplete=true
  say "${names[$1]}: $2"
}
live=()
phase=reachability
for i in "${!names[@]}"; do
  if fleet_ssh "$i" 'hostname' >"$tmp/probe" 2>&1; then
    live+=("$i")
    outcomes[$i]="reachable; not yet verified"
  else
    skip "$i" "unreachable or untrusted SSH host"
    printf '%s\n' "$(<"$tmp/probe")" >&2
  fi
done
(( ${#live[@]} )) || die "no selected hosts reachable; verify SSH access and host keys independently"

phase=publication
# CI supplies the paths so ARM import-from-derivation never runs on the Mac.
runs_json="$(timeout 60 gh run list \
  --repo "$GH_REPO" \
  --workflow host-build-cache.yml \
  --branch main \
  --status success \
  --event push \
  --json databaseId,headSha,headBranch,status,conclusion,event \
  --limit 1)" || die "cannot query CI workflow runs for $GH_REPO"
jq -e 'type == "array" and all(.[];
  (.databaseId | type == "number" and . > 0 and floor == .) and
  (.headSha | type == "string" and test("^[0-9a-f]{40}$")) and
  .headBranch == "main" and .status == "completed" and
  .conclusion == "success" and .event == "push")' <<< "$runs_json" >/dev/null ||
  die "malformed or ineligible CI run list response"
[[ "$(jq 'length' <<< "$runs_json")" -gt 0 ]] ||
  die "no successful host-build-cache.yml runs on main found; push to main and wait for CI"

run_id="$(jq -r '.[0].databaseId' <<< "$runs_json")"
manifest_sha="$(jq -r '.[0].headSha' <<< "$runs_json")"
if ! timeout 120 gh run download "$run_id" --repo "$GH_REPO" \
    --name fleet-host-paths --dir "$tmp/manifest-dl" >"$tmp/dl.log" 2>&1; then
  printf '%s\n' "$(<"$tmp/dl.log")" >&2
  die "cannot download fleet-host-paths artifact for latest successful CI run $run_id.
Bootstrap: push to main, wait for host-build-cache.yml (with collect-paths job) to succeed,
then retry.  If the workflow lacks a collect-paths job, update .github/workflows/host-build-cache.yml first."
fi

manifest_file="$tmp/manifest-dl/fleet-host-paths.json"
[[ -f "$manifest_file" ]] || die "fleet-host-paths artifact has no fleet-host-paths.json"
jq -e 'type == "object" and (.headSha | type == "string") and
  (.paths | type == "object" and
    keys == (["raspberrytimemachine","vidbox","nixpi4-bare","nixpi5","proxy"] | sort) and
    all(.[]; type == "string" and test("^/nix/store/[a-z0-9]{32}-nixos-system-[A-Za-z0-9._+-]+$")))' \
  "$manifest_file" >/dev/null || die "fleet-host-paths.json has unexpected structure; re-check CI collect-paths job"
manifest_sha_check="$(jq -r '.headSha' "$manifest_file")"
[[ "$manifest_sha_check" == "$manifest_sha" ]] ||
  die "manifest headSha ($manifest_sha_check) does not match run headSha ($manifest_sha)"

head_sha="$manifest_sha"
say "Selected CI run $run_id (commit ${head_sha:0:12})"

phase=cache
for i in "${live[@]}"; do
  name="${names[$i]}"
  path="$(jq -r --arg h "$name" '.paths[$h] // empty' "$manifest_file")"
  if [[ -z "$path" ]]; then
    skip "$i" "no closure path in CI manifest for $name"
    continue
  fi
  [[ "$path" =~ ^/nix/store/[a-z0-9]{32}-nixos-system-[A-Za-z0-9._+-]+$ ]] ||
    die "unexpected closure path for $name: $path"
  if ! timeout 60 nix --extra-experimental-features nix-command path-info \
      --store "$CACHIX_URL" \
      --option trusted-public-keys "$CACHIX_KEY" \
      --option require-sigs true \
      "$path" >"$tmp/cache.log" 2>&1; then
    skip "$i" "cache unavailable, missing or unverifiable toplevel"
    printf '%s\n' "$(<"$tmp/cache.log")" >&2
    continue
  fi
  paths[$i]="$path"
  ready+=("$i")
  outcomes[$i]="cached toplevel verified"
done
(( ${#ready[@]} )) || die "no selected hosts have a verifiable cached closure"

running_path() {
  local result
  # readlink -e: fails if the final path component does not exist, so a
  # partial/missing store path cannot look like a valid running system.
  result="$(fleet_ssh "$1" 'readlink -e /run/current-system')" || return 1
  [[ "$result" =~ ^/nix/store/[a-z0-9]{32}-nixos-system-[A-Za-z0-9._+-]+$ ]] || return 1
  printf '%s\n' "$result"
}
healthy() {
  local result
  result="$(fleet_ssh "$1" "/run/current-system/sw/bin/bash -s" <<'REMOTE_HEALTH'
set -euo pipefail
units="$(systemctl --failed --no-legend --plain --no-pager)" || exit 1
if [[ -n "$units" ]]; then printf '%s\n' "$units" >&2; exit 1; fi
printf 'HEALTHY\n'
REMOTE_HEALTH
  )" || return 1
  [[ "$result" == HEALTHY ]]
}
reboot_needed_probe() {
  # Userspace-only changes do not require a reboot.
  local i="$1" new_path="$2" reboot_args
  printf -v reboot_args '%q' "$new_path"
  fleet_ssh_t 30 "$i" \
    "/run/current-system/sw/bin/bash -s -- $reboot_args" \
    <<'REMOTE_REBOOT_CHECK'
set -euo pipefail
new_system="$1"
# Require existing artifacts, not merely symlink targets.
booted_k="$(readlink -e /run/booted-system/kernel)" \
  || { printf 'ERR:booted-kernel\n'; exit 1; }
booted_i="$(readlink -e /run/booted-system/initrd)" \
  || { printf 'ERR:booted-initrd\n'; exit 1; }
booted_m="$(readlink -e /run/booted-system/kernel-modules)" \
  || { printf 'ERR:booted-modules\n'; exit 1; }
new_k="$(readlink -e "$new_system/kernel")" \
  || { printf 'ERR:new-kernel\n'; exit 1; }
new_i="$(readlink -e "$new_system/initrd")" \
  || { printf 'ERR:new-initrd\n'; exit 1; }
new_m="$(readlink -e "$new_system/kernel-modules")" \
  || { printf 'ERR:new-modules\n'; exit 1; }
if [[ "$booted_k" != "$new_k" || "$booted_i" != "$new_i" || "$booted_m" != "$new_m" ]]; then
  printf 'REBOOT\n'
else
  printf 'CURRENT\n'
fi
REMOTE_REBOOT_CHECK
}
schedule_and_verify_reboot() {
  local i="$1"
  say "${names[$i]}: reboot required (kernel/initrd/modules changed); scheduling..."

  # Capture and validate the boot ID before triggering the reboot.  A valid
  # /proc/sys/kernel/random/boot_id is always a lowercase UUID.
  local boot_id_before=""
  if ! boot_id_before="$(fleet_ssh "$i" 'cat /proc/sys/kernel/random/boot_id' 2>/dev/null)"; then
    skip "$i" "failed to read boot ID before reboot"
    return 1
  fi
  [[ "$boot_id_before" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]] || {
    skip "$i" "boot ID before reboot has unexpected shape: $boot_id_before"
    return 1
  }

  local reboot_status=0
  fleet_ssh "$i" "sudo -n /run/current-system/sw/bin/systemctl reboot" \
    >"$tmp/reboot.log" 2>&1 || reboot_status=$?
  case "$reboot_status" in
    0) ;;
    124|255)
      say "${names[$i]}: reboot connection interrupted; checking for a new boot" ;;
    *)
      printf '%s\n' "$(<"$tmp/reboot.log")" >&2
      skip "$i" "reboot request failed (status $reboot_status)"
      return 1 ;;
  esac

  # Poll for a *different* boot ID.  The host may still respond with the old
  # ID for a brief window after the reboot command; only a freshly read ID that
  # differs from boot_id_before proves the system has rebooted.
  local attempt current_id remaining deadline=$((SECONDS + 300))
  for (( attempt=1; attempt<=30; attempt++ )); do
    sleep 10
    remaining=$((deadline - SECONDS))
    (( remaining > 0 )) || break
    (( remaining <= 30 )) || remaining=30
    if current_id="$(fleet_ssh_t "$remaining" "$i" 'cat /proc/sys/kernel/random/boot_id' 2>/dev/null)" \
        && [[ "$current_id" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ &&
              "$current_id" != "$boot_id_before" ]]; then
      return 0
    fi
    say "${names[$i]}: waiting for reboot ($attempt/30)..."
  done

  skip "$i" "host did not return with a changed boot ID within 5 minutes"
  return 1
}
if $check_only; then
  phase=inspection
  for i in "${ready[@]}"; do
    if ! current="$(running_path "$i")"; then
      skip "$i" "running-closure probe failed"
    elif [[ "$current" == "${paths[$i]}" ]]; then
      outcomes[$i]="already current"
    else
      outcomes[$i]="update available"
    fi
  done
  exit 0
fi

phase=prefetch
prefetched=()
for i in "${ready[@]}"; do
  new_path="${paths[$i]}"
  say "${names[$i]}: fetching closure..."
  local_args=""
  printf -v local_args '%q ' "$new_path" "$CACHIX_URL" "$CACHIX_KEY" "$UPSTREAM_URL" "$UPSTREAM_KEY"
  if ! fleet_ssh_t 3600 "$i" \
      "sudo -n /run/current-system/sw/bin/bash -s -- $local_args" \
      <<'REMOTE_FETCH' >"$tmp/prefetch.log" 2>&1
set -euo pipefail
new_system="$1" cachix_url="$2" cachix_key="$3" upstream_url="$4" upstream_key="$5"
exec nix-store --realise \
  --max-jobs 0 --builders "" \
  --option substituters "$cachix_url $upstream_url" \
  --option trusted-public-keys "$cachix_key $upstream_key" \
  --option require-sigs true --option fallback false \
  "$new_system"
REMOTE_FETCH
  then
    skip "$i" "prefetch failed"
    printf '%s\n' "$(<"$tmp/prefetch.log")" >&2
    continue
  fi
  outcomes[$i]="prefetched"
  prefetched+=("$i")
done
$prefetch_only && exit 0

phase=activation
for i in "${prefetched[@]}"; do
  new_path="${paths[$i]}"

  if ! current="$(running_path "$i")"; then
    skip "$i" "running-closure probe failed"
    continue
  fi

  if [[ "$current" != "$new_path" ]]; then
    say "${names[$i]}: activating (${notes[$i]})..."

    # Backup activity is informational in unattended fleet mode.
    if [[ "${names[$i]}" == raspberrytimemachine ]]; then
      if samba_result="$(fleet_ssh "$i" "/run/current-system/sw/bin/bash -s" <<'REMOTE_SAMBA'
set -euo pipefail
status="$(sudo -n smbstatus -b)" || exit 1
count=0
while IFS= read -r line; do
  [[ "$line" != *timemachine* ]] || count=$((count + 1))
done <<< "$status"
printf 'OK:%s\n' "$count"
REMOTE_SAMBA
      )" && [[ "$samba_result" =~ ^OK:([0-9]+)$ ]]; then
        n="${BASH_REMATCH[1]}"
        (( n == 0 )) || say "${names[$i]}: $n Time Machine session(s) active; proceeding anyway"
      else
        say "${names[$i]}: note: could not probe Time Machine sessions; proceeding"
      fi
    fi
  fi

  local_args=""
  printf -v local_args '%q' "$new_path"
  activate_result=""
  if ! activate_result="$(fleet_ssh_t 300 "$i" \
        "sudo -n /run/current-system/sw/bin/bash -s -- $local_args" \
        <<'REMOTE_ACTIVATE' 2>"$tmp/activate.log"
set -euo pipefail
new_system="$1"
upgrade_state="$(systemctl show --property=ActiveState --value nixos-upgrade.service)" || exit 1
case "$upgrade_state" in
  inactive|failed) ;;
  *) printf 'UPGRADE_ACTIVE:%s\n' "$upgrade_state"; exit 0 ;;
esac
current="$(readlink -e /run/current-system)" || exit 1
persistent="$(readlink -e /nix/var/nix/profiles/system)" || exit 1
if [[ "$current" == "$new_system" && "$persistent" == "$new_system" ]]; then
  printf 'CURRENT\n'
  exit 0
fi
# A previous test activation also needs bootloader installation, not just a profile change.
nix-env --profile /nix/var/nix/profiles/system --set "$new_system" || exit 1
"$new_system/bin/switch-to-configuration" switch >&2 || exit 1
printf 'ACTIVATED\n'
REMOTE_ACTIVATE
  )"; then
    printf '%s\n' "$(<"$tmp/activate.log")" >&2
    skip "$i" "activation failed"
    continue
  fi

  case "$activate_result" in
    UPGRADE_ACTIVE:*)
      skip "$i" "nixos-upgrade.service is active (${activate_result#UPGRADE_ACTIVE:}); try again later"
      continue ;;
    ACTIVATED) outcomes[$i]="activated (no reboot needed)" ;;
    CURRENT) outcomes[$i]="already current and healthy" ;;
    *)
      skip "$i" "unexpected activation output"
      continue ;;
  esac

  reboot_probe_result=""
  if ! reboot_probe_result="$(reboot_needed_probe "$i" "$new_path")"; then
    skip "$i" "reboot probe failed: $reboot_probe_result"
    say "${names[$i]}: cannot determine if reboot is needed after activation; skipping host"
    continue
  fi
  case "$reboot_probe_result" in
    REBOOT)
      if ! schedule_and_verify_reboot "$i"; then continue; fi
      if [[ "$activate_result" == CURRENT ]]; then
        outcomes[$i]="rebooted (boot change pending from prior switch)"
      else
        outcomes[$i]="activated and rebooted"
      fi ;;
    CURRENT) ;;
    *)
      skip "$i" "unexpected reboot probe result"
      continue ;;
  esac
  # Post-activation/reboot verification
  if ! current="$(running_path "$i")" || [[ "$current" != "$new_path" ]]; then
    skip "$i" "post-activation path mismatch or probe failed"
    continue
  fi
  if ! healthy "$i"; then
    skip "$i" "post-activation health check failed"
    continue
  fi
  say "${names[$i]}: verified (${outcomes[$i]})"
done
