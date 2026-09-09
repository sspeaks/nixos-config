#!/usr/bin/env bash
set -euo pipefail

readonly CACHIX_URL="https://sspeaks-nix.cachix.org"
readonly CACHIX_KEY="sspeaks-nix.cachix.org-1:Umjs3o8MgvHklkotM8S4XBfTz+zEQCnyr8TFpIC9x+o="
readonly FLEET=(
  "raspberrytimemachine|192.168.5.106||Time Machine appliance"
  "vidbox|192.168.5.195||video and ai-coaching"
  "nixpi4-bare|192.168.5.16|nixpi4-bare|pogbot and boggle"
  "nixpi5|192.168.5.238||Authentik SSO and home services"
  "proxy|20.83.103.87||public edge"
)
readonly NOT_FLEET=(
  "nixpi|alternate travel-router configuration of the same Pi 4 as nixpi4-bare"
  "vm|scratch VM"
  "asahi|laptop updated manually"
  "NixOS-WSL|desktop WSL instance, not always-on"
  "NixOS-WSL-work|work WSL instance, not always-on"
)

repo="${FLEET_DEFAULT_REPO:-$PWD}"
deploy_command="${FLEET_DEPLOY:-deploy}"
promotion_command="$deploy_command"
if [[ -n "${FLEET_DEFAULT_REPO:-}" && -x "$FLEET_DEFAULT_REPO/deploy" ]]; then
  promotion_command="$FLEET_DEFAULT_REPO/deploy"
fi
do_update=true
check_only=false
prefetch_only=false
auto_merge=false
only_hosts=()
names=() targets=() aliases=() notes=() outcomes=() paths=() ready=()
tmp=""
phase="arguments"
summary_enabled=false
incomplete=false

say() { printf '%s\n' "$*"; }
die() { printf 'ERROR [%s]: %s\n' "$phase" "$*" >&2; exit 1; }
usage() {
  printf '%s\n' \
    'Usage: ./update-fleet [options]' \
    '  --check          Inspect reachability, cache availability and drift.' \
    '  --no-update      Use this reviewed checkout without GitHub operations.' \
    '  --only HOST      Select a fleet host (repeatable).' \
    '  --prefetch-only  Populate target stores; do not activate.' \
    '  --auto-merge     Merge after passing PR checks without a merge prompt.' \
    '  --repo PATH      Checkout to use (default: launcher checkout).' \
    '  -h, --help       Show help.' \
    '' \
    'Nix supplies local tools; GitHub authentication and trusted SSH access' \
    'must already be configured. Activation always needs a terminal.' \
    'Check-only may fetch local tooling/metadata, but does not change Git or targets.' \
    'Incomplete selected-host runs exit nonzero; drift alone in --check does not.' \
    'Test activation leaves the boot default unchanged. Use the printed command to promote.'
}
finish() {
  local status=$? i
  trap - EXIT
  if $summary_enabled; then
    say ""
    say "Selected-host results:"
    for i in "${!names[@]}"; do
      printf '  %-24s %s\n' "${names[$i]}" "${outcomes[$i]}"
    done
  fi
  if [[ -n "$tmp" ]]; then
    rm -rf -- "$tmp"
  fi
  if $incomplete && (( status == 0 )); then status=1; fi
  exit "$status"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

while (( $# )); do
  case "$1" in
    --check) check_only=true ;;
    --no-update) do_update=false ;;
    --prefetch-only) prefetch_only=true ;;
    --auto-merge) auto_merge=true ;;
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
if $auto_merge && { $check_only || ! $do_update; }; then
  die "--auto-merge requires update mode"
fi
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
for command in nix git ssh jq timeout mktemp date rm sleep; do
  command -v "$command" >/dev/null || die "missing runtime command: $command; use the Nix launcher"
done
if ! $check_only; then
  command -v "$deploy_command" >/dev/null || die "missing packaged deploy helper"
fi
if $do_update && ! $check_only; then
  command -v gh >/dev/null || die "missing runtime command: gh; use the Nix launcher"
  timeout 30 gh auth status ||
    die "GitHub authentication is required; run gh auth login (README documents a temporary Nix shell)"
fi
if ! $check_only && ! $prefetch_only; then
  [[ -t 0 && -t 1 ]] || die "activation requires a terminal; use --prefetch-only for unattended downloads"
elif $do_update && ! $check_only && ! $auto_merge; then
  [[ -t 0 && -t 1 ]] || die "merging requires a terminal or --auto-merge"
fi
repo="$(cd "$repo" && pwd -P)" || die "cannot enter checkout: $repo"
[[ -f "$repo/flake.nix" ]] || die "checkout has no flake.nix: $repo"
git -C "$repo" rev-parse --is-inside-work-tree >/dev/null || die "not a Git checkout"
cd "$repo"
if ! $check_only; then
  clean="$(git status --porcelain)" || die "could not inspect Git status"
  [[ -z "$clean" ]] || die "checkout is dirty (including untracked files); commit/stash first"
fi
tmp="$(mktemp -d "${TMPDIR:-/tmp}/update-fleet.XXXXXXXX")" || die "could not create private temporary directory"
summary_enabled=true

nix_eval() {
  timeout 300 nix --extra-experimental-features "nix-command flakes" eval \
    --read-only --accept-flake-config --no-update-lock-file --no-write-lock-file "$@"
}
if ! host_json="$(nix_eval --json ".#nixosConfigurations" --apply builtins.attrNames)"; then
  die "could not evaluate host names in $repo"
fi
jq -e 'type == "array" and all(.[]; type == "string")' <<< "$host_json" >/dev/null ||
  die "invalid host-name evaluation output"
for entry in "${FLEET[@]}"; do
  name="${entry%%|*}"
  jq -e --arg name "$name" 'index($name) != null' <<< "$host_json" >/dev/null ||
    die "fleet host $name is absent from the selected checkout $repo"
done
while IFS= read -r name; do
  managed=false
  for entry in "${FLEET[@]}"; do [[ "${entry%%|*}" == "$name" ]] && managed=true; done
  $managed && continue
  excluded=false
  for entry in "${NOT_FLEET[@]}"; do
    if [[ "${entry%%|*}" == "$name" ]]; then
      say "Not fleet-managed: $name (${entry#*|})"
      excluded=true
      break
    fi
  done
  $excluded || say "WARNING: unmanaged configuration: $name"
done < <(jq -r '.[]' <<< "$host_json")

fleet_ssh() {
  local i="$1"
  shift
  local opts=(-o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=yes
    -o ServerAliveInterval=5 -o ServerAliveCountMax=2)
  [[ -z "${aliases[$i]}" ]] || opts+=(-o "HostKeyAlias=${aliases[$i]}")
  timeout 30 ssh "${opts[@]}" "sspeaks@${targets[$i]}" "$@"
}
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
if $do_update && ! $check_only; then
  timeout 120 git fetch --no-tags origin '+refs/heads/main:refs/remotes/origin/main' ||
    die "cannot refresh origin/main"
  before="$(git rev-parse HEAD)" || die "cannot resolve HEAD"
  main="$(git rev-parse refs/remotes/origin/main)" || die "cannot resolve origin/main"
  [[ "$before" == "$main" ]] || die "start updates from current origin/main; reconcile your checkout first"
  timeout 1800 nix --extra-experimental-features "nix-command flakes" flake update --accept-flake-config ||
    die "input update failed; inspect the checkout before retrying"
  if git diff --quiet --exit-code -- flake.lock; then
    say "flake.lock unchanged; nothing to publish"
  else
    diff_status=$?
    (( diff_status == 1 )) || die "cannot inspect lock changes"
    branch="fleet-update-$(date +%Y%m%d-%H%M%S)-$$"
    git switch -c "$branch" || die "cannot create update branch; lock changes retained"
    git add -- flake.lock || die "cannot stage flake.lock"
    git commit -m "Update flake inputs" || die "cannot commit; changes retained on $branch"
    update_sha="$(git rev-parse HEAD)" || die "cannot resolve update commit"
    timeout 120 git push --no-verify origin "HEAD:refs/heads/$branch" || die "cannot push $branch"
    pr="$(timeout 60 gh pr create --base main --head "$branch" \
      --title "Update flake inputs" \
      --body "Routine fleet update. CI publishes signed closures; targets never build.")" ||
      die "cannot create PR for $branch; inspect GitHub before retrying"
    [[ -n "$pr" ]] || die "GitHub returned no PR URL"
    say "Waiting for checks: $pr"
    checks_passed=false
    for (( attempt=0; attempt<40; attempt++ )); do
      pr_head="$(timeout 30 gh pr view "$pr" --json headRefOid -q .headRefOid)" ||
        die "cannot query $pr"
      [[ "$pr_head" == "$update_sha" ]] || die "PR head changed; review the new commit manually"
      # gh exits 8 for pending checks and 1 for failing or absent checks.
      check_status=0
      timeout 30 gh pr checks "$pr" --json name,bucket,workflow >"$tmp/checks.json" 2>"$tmp/checks.err" ||
        check_status=$?
      if ! jq -e 'type == "array" and all(.[]; (.name | type == "string") and (.bucket | type == "string"))' \
          "$tmp/checks.json" >/dev/null 2>&1; then
        die "cannot query PR checks: $(<"$tmp/checks.err")"
      fi
      (( check_status == 0 || check_status == 1 || check_status == 8 )) ||
        die "PR check request failed (status $check_status): $(<"$tmp/checks.err")"
      if jq -e 'any(.[]; .bucket == "fail" or .bucket == "cancel")' "$tmp/checks.json" >/dev/null; then
        die "PR checks failed or were cancelled; inspect $pr"
      fi
      if (( check_status == 0 )) && jq -e \
          'any(.[]; .workflow == "Flake Check" and .name == "check" and .bucket == "pass") and all(.[]; .bucket == "pass" or .bucket == "skipping")' \
          "$tmp/checks.json" >/dev/null; then
        checks_passed=true
        break
      fi
      sleep 30
    done
    $checks_passed || die "timed out waiting for successful Flake Check on $update_sha"
    if ! $auto_merge; then
      read -r -p "Merge $pr and continue? [yes/NO] " reply || die "no merge confirmation received"
      [[ "$reply" == yes ]] || die "merge declined; PR and branch retained"
    fi
    timeout 60 gh pr merge "$pr" --merge --match-head-commit "$update_sha" ||
      die "merge failed; inspect $pr"
    merged="$(timeout 30 gh pr view "$pr" --json state,mergeCommit)" || die "cannot resolve merged PR"
    merge_sha="$(jq -er 'select(.state == "MERGED") | .mergeCommit.oid | select(test("^[0-9a-f]{40}$"))' <<< "$merged")" ||
      die "PR has not merged to a known commit"
    timeout 120 git fetch --no-tags origin '+refs/heads/main:refs/remotes/origin/main' ||
      die "cannot refresh merged main"
    git merge-base --is-ancestor "$merge_sha" refs/remotes/origin/main ||
      die "merge commit is not reachable from origin/main"
    # Stay on the exact reviewed merge even if main advances during CI.
    git switch --detach "$merge_sha" || die "cannot select merged commit; reconcile local changes"
    say "Selected merged commit $merge_sha (detached HEAD)."
    build_done=false
    for (( attempt=0; attempt<80; attempt++ )); do
      runs="$(timeout 30 gh run list --workflow host-build-cache.yml --commit "$merge_sha" \
        --event push --limit 1 --json databaseId,status,conclusion,headSha)" ||
        die "cannot query cache workflow for $merge_sha"
      jq -e 'type == "array"' <<< "$runs" >/dev/null || die "malformed cache workflow response"
      if [[ "$(jq 'length' <<< "$runs")" != 0 ]]; then
        [[ "$(jq -r '.[0].headSha' <<< "$runs")" == "$merge_sha" ]] ||
          die "cache workflow does not match selected commit"
        if [[ "$(jq -r '.[0].status' <<< "$runs")" == completed ]]; then
          [[ "$(jq -r '.[0].conclusion' <<< "$runs")" == success ]] ||
            die "cache workflow failed: $(jq -c '.[0]' <<< "$runs")"
          build_done=true
          break
        fi
      fi
      sleep 30
    done
    $build_done || die "timed out waiting for published closures for $merge_sha"
  fi
fi

commit="$(git rev-parse --verify 'HEAD^{commit}')" || die "cannot resolve selected commit"
assert_checkout() {
  local current dirty
  current="$(git rev-parse HEAD)" || die "cannot resolve checkout"
  [[ "$current" == "$commit" ]] || die "checkout changed during the run; refusing a different commit"
  if ! $check_only; then
    dirty="$(git status --porcelain)" || die "cannot inspect checkout"
    [[ -z "$dirty" ]] || die "checkout became dirty during the run"
  fi
}
phase=cache
for i in "${live[@]}"; do
  assert_checkout
  if ! path="$(nix_eval --raw ".#nixosConfigurations.${names[$i]}.config.system.build.toplevel" 2>"$tmp/eval.err")"; then
    skip "$i" "evaluation failed (controller/IFD limitations may apply)"
    printf '%s\n' "$(<"$tmp/eval.err")" >&2
    continue
  fi
  [[ "$path" =~ ^/nix/store/[a-z0-9]{32}-nixos-system-[A-Za-z0-9._+-]+$ ]] ||
    die "unexpected closure path for ${names[$i]}: $path"
  if ! timeout 60 nix --extra-experimental-features nix-command path-info \
      --store "$CACHIX_URL" --option trusted-public-keys "$CACHIX_KEY" \
      --option require-sigs true "$path" >"$tmp/cache.log" 2>&1; then
    skip "$i" "cache unavailable, missing or unverifiable toplevel"
    printf '%s\n' "$(<"$tmp/cache.log")" >&2
    continue
  fi
  paths[$i]="$path"
  ready+=("$i")
  outcomes[$i]="cached toplevel; complete closure not yet fetched"
done
(( ${#ready[@]} )) || die "no selected hosts have a verifiable cached closure"

running_path() {
  local result
  result="$(fleet_ssh "$1" 'readlink -f /run/current-system')" || return 1
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
  assert_checkout
  exit 0
fi

deploy_host() {
  local i="$1" mode="$2"
  local args=(--flake-dir "$repo" --ssh-target "sspeaks@${targets[$i]}"
    --expected-commit "$commit" --expected-system-path "${paths[$i]}")
  [[ -z "${aliases[$i]}" ]] || args+=(--host-key-alias "${aliases[$i]}")
  "$deploy_command" "${args[@]}" "$mode" "${names[$i]}"
}
phase=prefetch
for i in "${ready[@]}"; do
  assert_checkout
  if deploy_host "$i" --dry-run >"$tmp/prefetch.log" 2>&1; then
    outcomes[$i]="prefetched"
  else
    outcomes[$i]="prefetch failed"
    printf '%s\n' "$(<"$tmp/prefetch.log")" >&2
    die "prefetch failed for ${names[$i]}; no hosts activated"
  fi
done
$prefetch_only && exit 0

phase=activation
for i in "${ready[@]}"; do
  assert_checkout
  if ! current="$(running_path "$i")"; then
    outcomes[$i]="running-closure probe failed"
    die "cannot inspect ${names[$i]}; stopping before later hosts"
  fi
  if [[ "$current" == "${paths[$i]}" ]]; then
    if healthy "$i"; then outcomes[$i]="already current and healthy"; continue; fi
    outcomes[$i]="already current but health check failed"
    die "${names[$i]} failed health checks; stopping"
  fi
  say "${names[$i]}: ${notes[$i]}"
  if [[ "${names[$i]}" == raspberrytimemachine ]]; then
    sessions=unknown
    if probe="$(fleet_ssh "$i" "/run/current-system/sw/bin/bash -s" <<'REMOTE_SAMBA'
set -euo pipefail
status="$(sudo -n smbstatus -b)" || exit 1
count=0
while IFS= read -r line; do
  [[ "$line" != *timemachine* ]] || count=$((count + 1))
done <<< "$status"
printf 'OK:%s\n' "$count"
REMOTE_SAMBA
    )" && [[ "$probe" =~ ^OK:([0-9]+)$ ]]; then
      sessions="${BASH_REMATCH[1]}"
    fi
    if [[ "$sessions" != 0 ]]; then
      say "Time Machine sessions: $sessions. Activation may interrupt a backup."
      if ! read -r -p "Activate anyway? [yes/NO] " reply || [[ "$reply" != yes ]]; then
        skip "$i" "activation declined (backup safety)"
        continue
      fi
    fi
  fi
  if deploy_host "$i" --test; then
    outcomes[$i]="test activated and confirmed"
  else
    outcomes[$i]="activation or health confirmation failed; inspect rollback guard"
    die "${names[$i]} failed; stopping before later hosts"
  fi
done

phase=verification
assert_checkout
for i in "${ready[@]}"; do
  [[ "${outcomes[$i]}" != "activation declined (backup safety)" ]] || continue
  if current="$(running_path "$i")" && [[ "$current" == "${paths[$i]}" ]] && healthy "$i"; then
    say "${names[$i]} verified; test activation still reverts on reboot."
    printf 'To promote manually: %q --flake-dir %q --expected-commit %q --expected-system-path %q --switch --ssh-target %q ' \
      "$promotion_command" "$repo" "$commit" "${paths[$i]}" "sspeaks@${targets[$i]}"
    [[ -z "${aliases[$i]}" ]] || printf '%s %q ' --host-key-alias "${aliases[$i]}"
    printf '%q\n' "${names[$i]}"
  else
    skip "$i" "final verification failed; investigate manually"
  fi
done
