#!/usr/bin/env bash
#
# Evaluate on the controller; realize a signed cached closure on the target.
# Unlike nixos-rebuild's build phase, target realization permits no builders.

set -euo pipefail

readonly CACHIX_CACHE_NAME="sspeaks-nix"
readonly CACHIX_URL="https://sspeaks-nix.cachix.org"
readonly CACHIX_PUBLIC_KEY="sspeaks-nix.cachix.org-1:Umjs3o8MgvHklkotM8S4XBfTz+zEQCnyr8TFpIC9x+o="
readonly UPSTREAM_URL="https://cache.nixos.org"
readonly UPSTREAM_PUBLIC_KEY="cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
readonly DEFAULT_ROLLBACK_MINUTES=10
readonly ROLLBACK_GUARD_PREFIX="nixos-laptop-deploy-rollback-guard"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

notice() {
  printf '%s\n' "$*"
}

usage() {
  cat <<'USAGE'
Usage: deploy [options] <nixosConfiguration>

Options:
  --dry-run                   Fetch the signed closure and show its diff,
                              without activation or changing the boot default.
  --test                      Temporary activation (default); rollback reboots
                              to the existing boot default.
  --switch                    Permanent activation after explicit confirmation.
                              Use only after a successful test.
  --rollback-minutes MINUTES   Dead-man guard duration, 1 through 60 (default 10).
  --flake-dir PATH             Clean reviewed checkout (default current directory).
  --ssh-target TARGET          OpenSSH destination (default configuration name).
  --host-key-alias ALIAS       Verify the SSH key against this known_hosts name.
  --expected-commit SHA        Require this full reviewed Git commit throughout.
  --expected-system-path PATH Require this exact evaluated NixOS store closure.
  -h, --help                  Show this help.

Example: deploy --ssh-target nixpi5-lan --host-key-alias nixpi5 nixpi5

The controller runtime is provisioned by the root launcher. Provide SSH
credentials and independently verified host keys; strict host-key checking is
always enabled. Targets require NixOS commands and passwordless sudo.
Cache-only: build and publish the exact reviewed commit in CI first. Missing
or incorrectly signed references stop deployment; all builders are disabled.
Fresh SSH, the exact running closure, and zero failed systemd units are required
before confirmation and checked again immediately before rollback is disarmed.
Also independently verify management access and affected services when prompted.
USAGE
}

require_command() {
  command -v "$1" >/dev/null 2>&1 ||
    die "Required command '$1' is not available."
}

valid_system_path() {
  [[ "$1" =~ ^/nix/store/[0-9abcdfghijklmnpqrsvwxyz]{32}-nixos-system-[A-Za-z0-9+._-]+$ ]]
}

activation_mode="test"
activation_mode_explicit=false
dry_run=false
rollback_minutes="$DEFAULT_ROLLBACK_MINUTES"
flake_dir="$PWD"
ssh_target=""
host_key_alias=""
expected_commit=""
expected_system_path=""
host=""

set_activation_mode() {
  local requested_mode="$1"
  if [[ "$activation_mode_explicit" == true && "$activation_mode" != "$requested_mode" ]]; then
    die "Choose only one activation mode: --test or --switch."
  fi
  activation_mode="$requested_mode"
  activation_mode_explicit=true
}

while (( $# > 0 )); do
  case "$1" in
    --dry-run) dry_run=true ;;
    --test) set_activation_mode "test" ;;
    --switch) set_activation_mode "switch" ;;
    --rollback-minutes|--flake-dir|--ssh-target|--host-key-alias|--expected-commit|--expected-system-path)
      (( $# >= 2 )) && [[ -n "$2" && "$2" != --* ]] ||
        die "$1 requires a value."
      case "$1" in
        --rollback-minutes) rollback_minutes="$2" ;;
        --flake-dir) flake_dir="$2" ;;
        --ssh-target) ssh_target="$2" ;;
        --host-key-alias) host_key_alias="$2" ;;
        --expected-commit) expected_commit="$2" ;;
        --expected-system-path) expected_system_path="$2" ;;
      esac
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    --)
      shift
      (( $# == 1 )) && [[ -z "$host" ]] ||
        die "Expected exactly one NixOS configuration."
      host="$1"
      ;;
    -*) die "Unknown option: $1" ;;
    *)
      [[ -z "$host" ]] ||
        die "Expected one NixOS configuration, received both '$host' and '$1'."
      host="$1"
      ;;
  esac
  shift
done

[[ -n "$host" ]] || { usage >&2; exit 2; }
[[ "$host" =~ ^[A-Za-z_][A-Za-z0-9_-]*$ ]] ||
  die "Invalid NixOS configuration '$host'."
if [[ ! "$rollback_minutes" =~ ^[1-9][0-9]?$ ]] || (( rollback_minutes > 60 )); then
  die "--rollback-minutes must be an integer from 1 through 60."
fi
[[ -z "$host_key_alias" || "$host_key_alias" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]*$ ]] ||
  die "--host-key-alias must be a known_hosts name containing only letters, digits, '.', '_' and '-'."
[[ -z "$expected_commit" || "$expected_commit" =~ ^([0-9a-f]{40}|[0-9a-f]{64})$ ]] ||
  die "--expected-commit must be a full lowercase hexadecimal Git commit."
[[ -z "$expected_system_path" ]] || valid_system_path "$expected_system_path" ||
  die "--expected-system-path must be a single NixOS system store path."
[[ -n "$ssh_target" ]] || ssh_target="$host"
[[ "$ssh_target" != -* && "$ssh_target" != *[!A-Za-z0-9_.@:%+\[\]-]* ]] ||
  die "--ssh-target must be an OpenSSH destination, not an option or shell expression."

for required_command in git nix ssh timeout; do
  require_command "$required_command"
done

flake_dir="$(cd "$flake_dir" && pwd -P)" ||
  die "Cannot enter flake directory '$flake_dir'."
[[ -f "$flake_dir/flake.nix" ]] ||
  die "'$flake_dir' does not contain flake.nix. Set --flake-dir to nixos-config."
git -C "$flake_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
  die "'$flake_dir' is not a Git checkout. Deploy an immutable reviewed checkout."

verify_checkout() {
  local current_commit checkout_status
  checkout_status="$(git -C "$flake_dir" status --porcelain)" ||
    die "Cannot inspect checkout status."
  [[ -z "$checkout_status" ]] ||
    die "Refusing a dirty checkout (including untracked files). Commit/stash changes, then deploy the reviewed commit."
  current_commit="$(git -C "$flake_dir" rev-parse --verify 'HEAD^{commit}')" ||
    die "Could not resolve the current checkout to a commit."
  [[ "$current_commit" == "$commit" ]] ||
    die "Checkout commit drift: expected '$commit', found '$current_commit'."
}

commit="$(git -C "$flake_dir" rev-parse --verify 'HEAD^{commit}')" ||
  die "Could not resolve the current checkout to a commit."
[[ -z "$expected_commit" || "$commit" == "$expected_commit" ]] ||
  die "Checkout commit does not match --expected-commit '$expected_commit'."
verify_checkout
if ! timeout --foreground 120 git -C "$flake_dir" fetch --no-tags origin '+refs/heads/main:refs/remotes/origin/main'; then
  die "Could not refresh origin/main. Refusing deployment because the reviewed-commit check cannot be made."
fi
if ! git -C "$flake_dir" merge-base --is-ancestor "$commit" refs/remotes/origin/main; then
  die "Refusing to deploy '$commit': it is not reachable from origin/main. Merge/review it first."
fi
cd "$flake_dir"

nix_eval() {
  timeout --foreground 300 nix --extra-experimental-features "nix-command flakes" \
    eval --raw --read-only --accept-flake-config --no-update-lock-file --no-write-lock-file "$1"
}

if ! system_path="$(nix_eval ".#nixosConfigurations.$host.config.system.build.toplevel")"; then
  die "Local flake evaluation failed for nixosConfigurations.$host. The target was not contacted."
fi
valid_system_path "$system_path" ||
  die "The '$host' toplevel did not evaluate to a NixOS system closure: '$system_path'."
[[ -z "$expected_system_path" || "$system_path" == "$expected_system_path" ]] ||
  die "Evaluated closure does not match --expected-system-path '$expected_system_path'."

if ! expected_system="$(nix_eval ".#nixosConfigurations.$host.pkgs.stdenv.hostPlatform.system")"; then
  die "Could not evaluate the target platform for '$host'. The target was not contacted."
fi
case "$expected_system" in
  aarch64-linux|x86_64-linux) ;;
  *) die "Unsupported target platform '$expected_system' for '$host'." ;;
esac
verify_checkout

notice "Reviewed commit: $commit"
notice "NixOS configuration: $host ($expected_system)"
notice "SSH target: $ssh_target"
notice "Cached system closure: $system_path"
notice "Checking public Cachix cache '$CACHIX_CACHE_NAME' ..."
if ! timeout --foreground 120 nix --extra-experimental-features nix-command path-info \
  --store "$CACHIX_URL" \
  --option trusted-public-keys "$CACHIX_PUBLIC_KEY" \
  --option require-sigs true \
  "$system_path" >/dev/null; then
  die "Cannot verify the Cachix top-level closure (cache miss, transport, or signature error; see above). Run the native CI host build for this exact commit and '$host'. No controller or target build will be attempted."
fi
notice "Top-level closure present in '$CACHIX_CACHE_NAME'."

ssh_options=(
  -o BatchMode=yes
  -o ConnectTimeout=15
  -o ConnectionAttempts=1
  -o StrictHostKeyChecking=yes
  -o ServerAliveInterval=15
  -o ServerAliveCountMax=3
  -o ControlMaster=no
  -o ControlPath=none
)
[[ -z "$host_key_alias" ]] || ssh_options+=(-o "HostKeyAlias=$host_key_alias")

remote() {
  timeout --foreground 120 ssh "${ssh_options[@]}" "$ssh_target" "$@"
}

notice "Checking remote NixOS prerequisites and passwordless sudo ..."
if ! remote "command -v sudo >/dev/null || { echo 'Missing remote sudo' >&2; exit 1; }; sudo -n /run/current-system/sw/bin/bash -s" <<'REMOTE_PREFLIGHT'
set -euo pipefail
for tool in bash nix nix-store nix-env systemctl systemd-run readlink stat flock rm; do
  command -v "$tool" >/dev/null 2>&1 || {
    printf 'Missing remote prerequisite: %s\n' "$tool" >&2
    exit 1
  }
done
for tool in bash nix nix-store systemctl; do
  [[ -x "/run/current-system/sw/bin/$tool" ]] || {
    printf 'Missing NixOS system executable: %s\n' "$tool" >&2
    exit 1
  }
done
[[ "$EUID" == 0 ]] || { echo 'Passwordless root sudo is required' >&2; exit 1; }
REMOTE_PREFLIGHT
then
  die "Remote preflight failed: check required NixOS commands, passwordless sudo, SSH credentials, and independently verified host-key trust. No target changes were attempted."
fi
if ! remote_arch="$(remote uname -m)"; then
  die "Cannot establish a new SSH connection to '$ssh_target'. Verify the destination and host-key alias; do not trust an unverified scanned key."
fi
case "$remote_arch" in
  aarch64|arm64) remote_system="aarch64-linux" ;;
  x86_64|amd64) remote_system="x86_64-linux" ;;
  *) die "Unsupported target machine architecture '$remote_arch'." ;;
esac
[[ "$remote_system" == "$expected_system" ]] ||
  die "Architecture mismatch: '$host' evaluates to '$expected_system', but '$ssh_target' reports '$remote_system'. No closure was copied or activated."

notice "Substituting the complete signed closure from the two pinned trusted caches."
notice "Local and remote builders and build fallback are disabled."
if ! timeout --foreground 3600 ssh "${ssh_options[@]}" "$ssh_target" \
  "sudo -n /run/current-system/sw/bin/bash -s -- $system_path $CACHIX_URL $CACHIX_PUBLIC_KEY $UPSTREAM_URL '$UPSTREAM_PUBLIC_KEY'" <<'REMOTE_FETCH'
set -euo pipefail
new_system="$1"
cachix_url="$2"
cachix_public_key="$3"
upstream_url="$4"
upstream_public_key="$5"
exec /run/current-system/sw/bin/nix-store --realise \
  --max-jobs 0 \
  --builders "" \
  --option substituters "$cachix_url $upstream_url" \
  --option trusted-public-keys "$cachix_public_key $upstream_public_key" \
  --option require-sigs true \
  --option fallback false \
  "$new_system"
REMOTE_FETCH
then
  die "The pinned signed caches could not supply the complete closure (missing reference, signature, transport, or timeout error; see above). No local or remote build was permitted. No activation was attempted and the system profile is unchanged."
fi

notice "== Closure diff: current system -> $system_path =="
if ! remote sudo -n /run/current-system/sw/bin/nix \
  --extra-experimental-features nix-command \
  store diff-closures /run/current-system "$system_path"; then
  die "Could not calculate the remote closure diff. No activation was attempted."
fi
verify_checkout
if [[ "$dry_run" == true ]]; then
  notice "Dry run complete: no running configuration, profile, boot default, or service state changed."
  notice "The target Nix store may now contain the signed closure solely so the exact diff could be shown."
  exit 0
fi

[[ -t 0 && -t 1 ]] ||
  die "Refusing non-interactive activation. Re-run from a terminal so confirmation is meaningful."
notice "No configuration has been activated yet."
if ! read -r -p "Type '$host' to arm the $rollback_minutes-minute rollback guard and run '$activation_mode': " confirmation; then
  die "No confirmation received. No activation was attempted."
fi
[[ "$confirmation" == "$host" ]] || {
  notice "Confirmation did not match. No activation was attempted."
  exit 1
}
verify_checkout

rollback_seconds=$(( rollback_minutes * 60 ))
rollback_guard_unit="$ROLLBACK_GUARD_PREFIX-$$"
rollback_guard_marker="/run/$ROLLBACK_GUARD_PREFIX.armed"
notice "Arming target-side rollback guard '$rollback_guard_unit' before activation."
if ! timeout --foreground 3600 ssh "${ssh_options[@]}" "$ssh_target" \
  "sudo -n /run/current-system/sw/bin/bash -s -- $system_path $activation_mode $rollback_seconds $rollback_guard_unit $rollback_guard_marker" <<'REMOTE_SCRIPT'
set -euo pipefail
new_system="$1"
mode="$2"
rollback_seconds="$3"
guard_unit="$4"
guard_marker="$5"

die() { printf 'REMOTE ERROR: %s\n' "$*" >&2; exit 1; }
case "$mode" in test|switch) ;; *) die "unsupported activation mode";; esac
[[ -x "$new_system/bin/switch-to-configuration" ]] ||
  die "the imported closure has no switch-to-configuration executable"
[[ "$guard_marker" == "/run/nixos-laptop-deploy-rollback-guard.armed" ]] ||
  die "refusing an unexpected rollback marker path"

umask 077
exec 9>"$guard_marker.lock"
flock -n -x 9 || die "another deployment or rollback is in progress"
[[ ! -e "$guard_marker" && ! -L "$guard_marker" ]] ||
  die "another rollback guard is already armed; do not overlap deployments"
upgrade_state="$(systemctl show --property=ActiveState --value nixos-upgrade.service)" ||
  die "cannot inspect nixos-upgrade.service"
case "$upgrade_state" in
  inactive|failed) ;;
  *) die "nixos-upgrade.service is active or its state is unknown" ;;
esac
persistent_system="$(readlink -f /nix/var/nix/profiles/system)"
for tool in nix-env bash systemctl flock; do
  [[ -x "$persistent_system/sw/bin/$tool" ]] ||
    die "the persisted system has no $tool for rollback"
done

printf '%s\n' "$guard_unit" > "$guard_marker"
# Serialize rollback execution and disarm, including the timer/stop race.
if ! systemd-run --quiet \
  --unit="$guard_unit" \
  --on-active="${rollback_seconds}s" \
  --timer-property=AccuracySec=1s \
  --service-type=oneshot \
  "$persistent_system/sw/bin/bash" -c '
    set -euo pipefail
    marker="$1"
    old_system="$2"
    mode="$3"
    unit="$4"
    exec 9>"$marker.lock"
    "$old_system/sw/bin/flock" -x 9
    [[ -f "$marker" && ! -L "$marker" ]] || exit 0
    [[ "$(< "$marker")" == "$unit" ]] || exit 0
    printf "%s:rolling-back\n" "$unit" > "$marker"
    if [[ "$mode" == test ]]; then
      exec "$old_system/sw/bin/systemctl" reboot
    fi
    "$old_system/sw/bin/nix-env" --profile /nix/var/nix/profiles/system --set "$old_system"
    "$old_system/bin/switch-to-configuration" switch
    rm -f "$marker"
  ' laptop-deploy-rollback "$guard_marker" "$persistent_system" "$mode" "$guard_unit"; then
  die "could not confirm rollback arming; marker retained, no activation attempted"
fi
systemctl is-active --quiet "$guard_unit.timer" ||
  die "systemd did not leave the rollback timer active; no activation attempted"
# Do not let a hung activation hold the lock needed by the dead-man callback.
flock -u 9
exec 9>&-
printf 'Rollback guard is armed for %ss. Activating %s with %s.\n' "$rollback_seconds" "$new_system" "$mode"
if [[ "$mode" == "switch" ]]; then
  "$persistent_system/sw/bin/nix-env" --profile /nix/var/nix/profiles/system --set "$new_system"
fi
"$new_system/bin/switch-to-configuration" "$mode"
REMOTE_SCRIPT
then
  die "Activation returned an error. Any armed target-side guard was intentionally left armed; do not retry blindly. Investigate independently and allow rollback to recover the prior configuration."
fi

wait_for_fresh_ssh() {
  local attempt
  for (( attempt = 1; attempt <= 12; attempt++ )); do
    if remote sudo -n /run/current-system/sw/bin/systemctl \
      is-active --quiet "$rollback_guard_unit.timer" >/dev/null 2>&1; then
      return 0
    fi
    printf 'Waiting for a fresh SSH connection after activation (%d/12) ...\n' "$attempt" >&2
    sleep 5
  done
  return 1
}

verify_health() {
  local health_result
  if ! health_result="$(remote "sudo -n /run/current-system/sw/bin/bash -s -- $system_path" <<'HEALTH_SCRIPT'
set -euo pipefail
expected_system="$1"
running_system="$(readlink -f /run/current-system)"
[[ "$running_system" == "$expected_system" ]] || {
  printf 'Wrong running closure: expected %s, found %s\n' "$expected_system" "$running_system" >&2
  exit 1
}
if ! failed_count="$(systemctl show --property=NFailedUnits --value)"; then
  echo 'Failed to query systemd failed-unit count' >&2
  exit 1
fi
if ! failed_units="$(systemctl list-units --failed --all --no-legend --plain --no-pager)"; then
  echo 'Failed to query systemd failed units' >&2
  exit 1
fi
[[ "$failed_count" == 0 && -z "$failed_units" ]] || {
  printf 'Unhealthy or malformed systemd result: failed count=%s\n%s\n' "$failed_count" "$failed_units" >&2
  exit 1
}
printf '%s\n' DEPLOY_HEALTH_OK
HEALTH_SCRIPT
  )"; then
    return 1
  fi
  [[ "$health_result" == DEPLOY_HEALTH_OK ]] || {
    printf 'Missing or malformed remote health acknowledgement: %s\n' "$health_result" >&2
    return 1
  }
}

notice "Checking a new SSH connection (connection multiplexing is disabled)."
wait_for_fresh_ssh ||
  die "Fresh SSH with an active rollback guard did not succeed. The guard remains armed; investigate independently."
verify_health ||
  die "Post-activation closure/systemd health verification failed. The rollback guard remains armed."
notice "Fresh SSH, exact running closure, and zero failed units verified."
notice "Independently verify the tunnel/management path and affected services before disarming."
if ! read -r -p "After those checks, type '$host' to disarm rollback: " final_confirmation; then
  die "No confirmation received. The rollback guard remains armed."
fi
[[ "$final_confirmation" == "$host" ]] || {
  notice "Confirmation did not match. The rollback guard remains armed."
  exit 1
}

if ! remote \
  "sudo -n /run/current-system/sw/bin/bash -s -- $rollback_guard_unit $rollback_guard_marker $system_path" <<'DISARM_SCRIPT'
set -euo pipefail
guard_unit="$1"
guard_marker="$2"
expected_system="$3"
die() { printf 'REMOTE ERROR: %s\n' "$*" >&2; exit 1; }

[[ "$guard_marker" == "/run/nixos-laptop-deploy-rollback-guard.armed" ]] ||
  die "unexpected rollback marker path"
exec 9>"$guard_marker.lock"
flock -n -x 9 || die "rollback execution or another deployment has already begun"
[[ -f "$guard_marker" && ! -L "$guard_marker" ]] ||
  die "rollback marker is missing or not a regular file"
[[ "$(stat -c %u "$guard_marker")" == 0 && "$(< "$guard_marker")" == "$guard_unit" ]] ||
  die "rollback marker is not owned by this deployment/root"

service_idle() {
  [[ "$(systemctl show --property=ActiveState --value "$guard_unit.service")" == inactive &&
     "$(systemctl show --property=SubState --value "$guard_unit.service")" == dead ]]
}
[[ "$(systemctl show --property=ActiveState --value "$guard_unit.timer")" == active &&
   "$(systemctl show --property=SubState --value "$guard_unit.timer")" == waiting ]] ||
  die "rollback timer is not active and waiting"
service_idle &&
  [[ "$(systemctl show --property=Result --value "$guard_unit.service")" == success ]] ||
  die "rollback service has begun or failed"

[[ "$(readlink -f /run/current-system)" == "$expected_system" ]] ||
  die "running closure changed before disarm"
failed_count="$(systemctl show --property=NFailedUnits --value)" ||
  die "failed-unit count probe failed before disarm"
failed_units="$(systemctl list-units --failed --all --no-legend --plain --no-pager)" ||
  die "failed-unit probe failed before disarm"
[[ "$failed_count" == 0 && -z "$failed_units" ]] ||
  die "systemd health failed before disarm: count=$failed_count; $failed_units"

timer_stopped=false
disarmed=false
restore_guard() {
  if [[ "$timer_stopped" == true && "$disarmed" != true ]]; then
    systemctl start "$guard_unit.timer" ||
      printf 'REMOTE ERROR: could not restore rollback timer; investigate immediately\n' >&2
  fi
}
trap restore_guard EXIT
trap 'exit 1' HUP INT TERM
# Mark first: even a failed/ambiguous stop must restore protection on exit.
timer_stopped=true
systemctl stop "$guard_unit.timer"
# A stopped transient timer may unload its never-started service, removing
# Result. Inactive/dead still rules out a callback waiting on our held lock.
service_idle ||
  die "rollback service started while stopping its timer; marker retained"
[[ "$(systemctl show --property=ActiveState --value "$guard_unit.timer")" == inactive ]] ||
  die "rollback timer did not stop"
rm "$guard_marker"
disarmed=true
DISARM_SCRIPT
then
  die "Could not safely disarm rollback. Treat the host as pending rollback and investigate from an independent console."
fi

if [[ "$activation_mode" == "test" ]]; then
  notice "Test activation confirmed. It remains live until reboot; the boot default is still the previous switched generation."
  notice "After validating it, rerun with --switch to make this exact cached closure persistent."
else
  notice "Switch activation confirmed and rollback guard disarmed."
fi
