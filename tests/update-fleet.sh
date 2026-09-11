#!/usr/bin/env bash
set -euo pipefail

implementation="$(realpath "${1:-scripts/update-fleet.sh}")"
workflow="$(realpath "${2:-.github/workflows/host-build-cache.yml}")"
export TEST_REAL_GIT
TEST_REAL_GIT="$(command -v git)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT
test_dir="$(cd "$test_dir" && pwd -P)"
mkdir -p "$test_dir/bin" "$test_dir/repo"
printf '{}\n' > "$test_dir/repo/flake.nix"
export FLEET_DEFAULT_REPO="$test_dir/repo"
export FLEET_GH_REPO="sspeaks/nixos-config"
export TEST_LOG="$test_dir/commands"
export TEST_CLOSURE="/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-nixos-system-fixture"
export TEST_COMMIT="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
export TEST_SCENARIO=normal

# Absolute bash path: the Nix check sandbox has no /usr/bin/env, so generated
# mock scripts must not rely on an env shebang.
bash_bin="$(command -v bash)"

printf '#!%s\n' "$bash_bin" >"$test_dir/bin/mock"
cat >>"$test_dir/bin/mock" <<'MOCK'
set -euo pipefail
cmd="${0##*/}"
printf '%s %s\n' "$cmd" "$*" >> "$TEST_LOG"
case "$cmd" in
  timeout) shift; exec "$@" ;;
  sleep) exit 0 ;;
  find)
    # For the manifest-dl search: create the file if the directory exists.
    if [[ "$*" == *"fleet-host-paths.json"* ]]; then
      for a in "$@"; do
        if [[ "$a" != -* && "$a" == */manifest-dl* ]]; then
          f="$a/fleet-host-paths.json"
          [[ -f "$f" ]] && printf '%s\n' "$f"
          break
        fi
      done
    fi ;;
  sudo)
    [[ "$TEST_SCENARIO" != sudo-fail && "$TEST_SCENARIO" != samba-unknown ]] || exit 1
    [[ "$1" != -n ]] || shift
    exec "$@" ;;
  smbstatus)
    case "$TEST_SCENARIO" in
      samba-fail) exit 1 ;;
      samba-active) printf '123 timemachine connected\n' ;;
      *) printf 'PID Username Group Machine\n' ;;
    esac ;;
  systemctl)
    case "$TEST_SCENARIO" in
      systemctl-fail) exit 1 ;;
      units-failed)
        # --failed lists failed units; show --property=ActiveState returns inactive
        [[ "$*" != *"--failed"* ]] || echo 'fixture.service loaded failed failed Fixture' ;;
      upgrade-active)
        # show --property=ActiveState returns active; --failed returns nothing
        [[ "$*" != *"ActiveState"* ]] || echo active ;;
      *)
        # --failed: no output (no failures); show --property=ActiveState: inactive
        [[ "$*" != *"ActiveState"* ]] || echo inactive ;;
    esac ;;
  readlink)
    [[ "$TEST_SCENARIO" != body-read-fail ]] || exit 1
    [[ "$1" == -e ]] || exit 97
    case "$2" in
      /run/current-system)
        if [[ "$TEST_SCENARIO" == body-current || "$TEST_SCENARIO" == body-test ]]; then
          echo "$TEST_BODY_SYSTEM"
        else echo /old-system; fi ;;
      /nix/var/nix/profiles/system)
        if [[ "$TEST_SCENARIO" == body-current ]]; then echo "$TEST_BODY_SYSTEM"
        else echo /old-system; fi ;;
      *) exit 97 ;;
    esac ;;
  nix-env|nix-store)
    [[ "$TEST_SCENARIO" != activate-fail ]] || exit 1 ;;
  git)
    if [[ "$TEST_SCENARIO" == linked-worktree ]]; then
      # Use real git for worktree operations; mock fetch/merge-base.
      case " $* " in
        *" fetch "*|*" merge-base "*) exit 0 ;;
        *) exec "$TEST_REAL_GIT" "$@" ;;
      esac
    fi
    case " $* " in
      *" --is-inside-work-tree "*) echo true ;;
      *" status --porcelain "*) exit 0 ;;
      *" rev-parse "*)
        echo "$TEST_COMMIT" ;;
      *" fetch "*) [[ "$TEST_SCENARIO" != fetch-fail ]] ;;
      *" merge-base "*) [[ "$TEST_SCENARIO" != sha-not-main ]] || exit 1; exit 0 ;;
      *) echo "Unexpected git invocation: $*" >&2; exit 97 ;;
    esac ;;
  nix)
    if [[ "$TEST_SCENARIO" == linked-worktree && "$PWD" != "$TEST_LINKED_CHECKOUT" ]]; then
      echo 'Evaluated the wrong checkout' >&2; exit 97
    fi
    case " $* " in
      *" builtins.attrNames "*)
        if [[ "$TEST_SCENARIO" == eval-fail ]]; then echo 'evaluation unavailable' >&2; exit 1; fi
        if [[ "$TEST_SCENARIO" == host-extra ]]; then
          printf '["raspberrytimemachine","vidbox","nixpi4-bare","nixpi5","proxy","vm","future-host"]\n'
        else printf '["raspberrytimemachine","vidbox","nixpi4-bare","nixpi5","proxy"]\n'; fi ;;
      *" eval "*)
        if [[ "$TEST_SCENARIO" == eval-fail ]]; then echo 'evaluation unavailable' >&2; exit 1; fi
        echo "$TEST_CLOSURE" ;;
      *" path-info "*)
        [[ "$TEST_SCENARIO" != cache-fail ]] || exit 1
        echo "$TEST_CLOSURE" ;;
      *) echo "Unexpected nix invocation: $*" >&2; exit 97 ;;
    esac ;;
  ssh)
    if [[ "$TEST_SCENARIO" == unreachable || ( "$TEST_SCENARIO" == partial && "$*" == *192.168.5.195* ) ]]; then
      echo 'SSH connection failed' >&2; exit 255
    fi
    case "$*" in
      *hostname*)
        # For reboot-timeout: hostname fails after the reboot is triggered.
        if [[ "$TEST_SCENARIO" == reboot-timeout && -e "$TEST_LOG.rebooted" ]]; then
          exit 255
        fi
        echo fixture ;;
      *"readlink"*"/run/current-system"*)
        [[ "$TEST_SCENARIO" != running-fail ]] || exit 255
        case "$TEST_SCENARIO" in
          reboot-needed|reboot-delayed)
            # Old before reboot, new after.
            if [[ -e "$TEST_LOG.rebooted" ]]; then echo "$TEST_CLOSURE"
            else echo /nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-nixos-system-old; fi ;;
          reboot-timeout|reboot-bad-bootid|reboot-invalid-bootid|reboot-refused)
            echo /nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-nixos-system-old ;;
          outdated)
            echo /nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-nixos-system-old ;;
          activate-ok|samba-active|reboot-probe-fail)
            # Old before activation, new after.
            if [[ -e "$TEST_LOG.activated" ]]; then echo "$TEST_CLOSURE"
            else echo /nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-nixos-system-old; fi ;;
          upgrade-active|activate-fail)
            echo /nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-nixos-system-old ;;
          *)
            echo "$TEST_CLOSURE" ;;
        esac ;;
      *"/proc/sys/kernel/random/boot_id"*)
        case "$TEST_SCENARIO" in
          reboot-bad-bootid)
            # Always returns the same valid UUID → detected as unchanged boot ID
            echo "aaaaaaaa-0000-0000-0000-000000000001" ;;
          reboot-timeout)
            # Host goes down for reboot and never comes back
            if [[ -e "$TEST_LOG.rebooted" ]]; then exit 255; fi
            echo "aaaaaaaa-0000-0000-0000-000000000001" ;;
          reboot-invalid-bootid)
            if [[ -e "$TEST_LOG.rebooted" ]]; then echo invalid
            else echo "aaaaaaaa-0000-0000-0000-000000000001"; fi ;;
          reboot-delayed)
            if [[ -e "$TEST_LOG.rebooted" && -e "$TEST_LOG.old-boot-observed" ]]; then
              echo "aaaaaaaa-0000-0000-0000-000000000002"
            else
              [[ ! -e "$TEST_LOG.rebooted" ]] || touch "$TEST_LOG.old-boot-observed"
              echo "aaaaaaaa-0000-0000-0000-000000000001"
            fi ;;
          *)
            if [[ -e "$TEST_LOG.rebooted" ]]; then echo "aaaaaaaa-0000-0000-0000-000000000002"
            else echo "aaaaaaaa-0000-0000-0000-000000000001"; fi ;;
        esac ;;
      *"systemctl reboot"*)
        [[ "$TEST_SCENARIO" != reboot-refused ]] || exit 1
        touch "$TEST_LOG.rebooted"; exit 0 ;;
      *"sudo"*"bash -s"*"$TEST_CLOSURE"*)
        # Dispatch on stdin body: REMOTE_FETCH, REMOTE_ACTIVATE, or REMOTE_PROFILE_SET.
        stdin_content="$(cat)"
        if printf '%s' "$stdin_content" | grep -q 'nix-store.*--realise'; then
          # REMOTE_FETCH
          [[ "$TEST_SCENARIO" != prefetch-fail ]] || exit 1
          [[ "$TEST_SCENARIO" != prefetch-fail-first || "$*" != *192.168.5.106* ]] || exit 1
        elif printf '%s' "$stdin_content" | grep -q 'switch-to-configuration'; then
          # REMOTE_ACTIVATE — returns ACTIVATED on success; reboot detection is
          # done by a separate REMOTE_REBOOT_CHECK probe below.
          case "$TEST_SCENARIO" in
            activate-fail|profile-fail) exit 1 ;;
            upgrade-active) printf 'UPGRADE_ACTIVE:active\n' ;;
            normal|already-current-reboot-needed|units-failed|reboot-probe-fail-first|prefetch-fail-first)
              printf 'CURRENT\n' ;;
            *)
              printf 'ACTIVATED\n'; touch "$TEST_LOG.activated" ;;
          esac
        else
          # REMOTE_PROFILE_SET — persistent profile update for already-current hosts.
          [[ "$TEST_SCENARIO" != profile-fail ]] || exit 1
          touch "$TEST_LOG.profile-set"
        fi ;;
      *"bash -s -- "*"$TEST_CLOSURE"*)
        # REMOTE_REBOOT_CHECK — consume stdin and return a canned result based on
        # whether the scenario expects a kernel/initrd/modules change.
        cat >/dev/null
        case "$TEST_SCENARIO" in
          reboot-needed|reboot-timeout|reboot-bad-bootid|already-current-reboot-needed|reboot-invalid-bootid|reboot-refused|reboot-delayed)
            printf 'REBOOT\n' ;;
          reboot-probe-fail)
            printf 'ERR:booted-kernel\n'; exit 1 ;;
          reboot-probe-fail-first)
            # Only raspberrytimemachine (192.168.5.106) fails; others return CURRENT
            if [[ "$*" == *192.168.5.106* ]]; then
              printf 'ERR:booted-kernel\n'; exit 1
            fi
            printf 'CURRENT\n' ;;
          *)
            printf 'CURRENT\n' ;;
        esac ;;
      *"/bash -s"*) exec bash -s ;;
      *) echo "Unexpected SSH invocation: $*" >&2; exit 97 ;;
    esac ;;
  gh)
    case "$*" in
      "auth status") [[ "$TEST_SCENARIO" != auth-fail ]] ;;
      "run list "*)
        case "$TEST_SCENARIO" in
          manifest-no-runs) echo '[]' ;;
          run-not-success)
            printf '[{"databaseId":42,"headSha":"%s","headBranch":"main","event":"push","status":"completed","conclusion":"failure"}]\n' "$TEST_COMMIT" ;;
          run-not-main)
            printf '[{"databaseId":42,"headSha":"%s","headBranch":"feature","event":"push","status":"completed","conclusion":"success"}]\n' "$TEST_COMMIT" ;;
          run-bad-sha)
            printf '[{"databaseId":42,"headSha":"bad","headBranch":"main","event":"push","status":"completed","conclusion":"success"}]\n' ;;
          *)
            printf '[{"databaseId":42,"headSha":"%s","headBranch":"main","event":"push","status":"completed","conclusion":"success"}]\n' "$TEST_COMMIT" ;;
        esac ;;
      "run download "*)
        case "$TEST_SCENARIO" in
          manifest-no-artifact) exit 1 ;;
        esac
        # Extract --dir argument value
        dir=""
        grab_next=false
        for a in "$@"; do
          if $grab_next; then dir="$a"; grab_next=false; break; fi
          [[ "$a" == "--dir" ]] && grab_next=true
        done
        [[ -n "$dir" ]] || { echo "no --dir in gh run download: $*" >&2; exit 97; }
        mkdir -p "$dir"
        case "$TEST_SCENARIO" in
          manifest-malformed)
            printf 'not-json-garbage' > "$dir/fleet-host-paths.json" ;;
          manifest-missing-host)
            # nixpi4-bare is absent
            printf '{"headSha":"%s","paths":{"raspberrytimemachine":"%s","vidbox":"%s","nixpi5":"%s","proxy":"%s"}}\n' \
              "$TEST_COMMIT" "$TEST_CLOSURE" "$TEST_CLOSURE" "$TEST_CLOSURE" "$TEST_CLOSURE" \
              > "$dir/fleet-host-paths.json" ;;
          manifest-wrong-sha)
            printf '{"headSha":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","paths":{"raspberrytimemachine":"%s","vidbox":"%s","nixpi4-bare":"%s","nixpi5":"%s","proxy":"%s"}}\n' \
              "$TEST_CLOSURE" "$TEST_CLOSURE" "$TEST_CLOSURE" "$TEST_CLOSURE" "$TEST_CLOSURE" \
              > "$dir/fleet-host-paths.json" ;;
          *)
            printf '{"headSha":"%s","paths":{"raspberrytimemachine":"%s","vidbox":"%s","nixpi4-bare":"%s","nixpi5":"%s","proxy":"%s"}}\n' \
              "$TEST_COMMIT" "$TEST_CLOSURE" "$TEST_CLOSURE" "$TEST_CLOSURE" "$TEST_CLOSURE" "$TEST_CLOSURE" \
              > "$dir/fleet-host-paths.json" ;;
        esac ;;
      *) echo "Unexpected gh invocation: $*" >&2; exit 97 ;;
    esac ;;
esac
MOCK
chmod +x "$test_dir/bin/mock"
for cmd in git nix ssh gh timeout sleep sudo smbstatus systemctl nix-env nix-store find; do
  ln -s mock "$test_dir/bin/$cmd"
done
export PATH="$test_dir/bin:$PATH"

run_case() {
  local scenario="$1" expected="$2"
  shift 2
  export TEST_SCENARIO="$scenario"
  : >"$TEST_LOG"
  rm -f "$TEST_LOG.rebooted" "$TEST_LOG.activated" "$TEST_LOG.profile-set" "$TEST_LOG.old-boot-observed"
  local status=0
  bash "$implementation" "$@" >"$test_dir/output" 2>&1 || status=$?
  if [[ "$status" != "$expected" ]]; then
    printf 'FAIL %s: wanted %s, got %s\n' "$scenario" "$expected" "$status" >&2
    cat "$test_dir/output" >&2
    exit 1
  fi
}
assert_output() { grep -q -- "$1" "$test_dir/output" || { cat "$test_dir/output" >&2; exit 1; }; }
assert_log()    { grep -q -- "$1" "$TEST_LOG" || { cat "$TEST_LOG" >&2; exit 1; }; }
reject_log()    { if grep -q -- "$1" "$TEST_LOG"; then cat "$TEST_LOG" >&2; exit 1; fi; }

# ---------------------------------------------------------------------------
# Help and argument parsing
# ---------------------------------------------------------------------------
run_case normal 0 --help
reject_log 'gh '

run_case normal 1 --check --only vidbox --only typo
assert_output 'unknown fleet host: typo'
reject_log 'ssh '

run_case normal 1 --check --prefetch-only
assert_output 'mutually exclusive'

# --auto-merge is removed; must produce an error immediately.
run_case normal 1 --auto-merge
assert_output 'no longer supported'

# --no-update is deprecated; must warn but still proceed.
run_case normal 0 --check --only vidbox --no-update
assert_output 'WARNING.*no-update.*deprecated'

# ---------------------------------------------------------------------------
# Auth / preflight failures
# ---------------------------------------------------------------------------
run_case auth-fail 1 --check --only vidbox
reject_log 'nix '

# ---------------------------------------------------------------------------
# Deployment needs neither local evaluation nor a refreshed Git checkout.
# ---------------------------------------------------------------------------
run_case eval-fail 0 --check --only vidbox
reject_log 'nix .*eval'
reject_log 'git fetch'

# ---------------------------------------------------------------------------
# Manifest / publication phase
# ---------------------------------------------------------------------------
run_case manifest-no-runs 1 --check --only vidbox
assert_output 'no successful host-build-cache.yml runs'

run_case manifest-no-artifact 1 --check --only vidbox
assert_output 'fleet-host-paths artifact'
assert_output 'Bootstrap'
[[ "$(grep -c '^gh run download ' "$TEST_LOG")" == 1 ]]
for scenario in run-not-success run-not-main run-bad-sha; do
  run_case "$scenario" 1 --check --only vidbox
  assert_output 'ineligible CI run'
  reject_log 'gh run download'
done

run_case manifest-malformed 1 --check --only vidbox
assert_output 'unexpected structure'

# Manifest with headSha mismatch (run sha vs json sha)
run_case manifest-wrong-sha 1 --check --only vidbox
assert_output 'does not match run headSha'

# ---------------------------------------------------------------------------
# Reachability
# ---------------------------------------------------------------------------
run_case unreachable 1 --check --only vidbox
assert_output 'unreachable'

run_case partial 1 --check --only vidbox --only nixpi5
assert_output 'unreachable'
assert_output 'already current'

# ---------------------------------------------------------------------------
# Cache phase
# ---------------------------------------------------------------------------
run_case cache-fail 1 --check --only vidbox
assert_output 'cache unavailable'

# Missing host in manifest: that host is skipped; rest continue.
run_case manifest-missing-host 1 --check --only nixpi4-bare
assert_output 'unexpected structure'

# ---------------------------------------------------------------------------
# Check mode (--check)
# ---------------------------------------------------------------------------
run_case normal 0 --check --only vidbox
assert_output 'already current'
reject_log 'deploy '

run_case outdated 0 --check --only vidbox
assert_output 'update available'

run_case running-fail 1 --check --only vidbox
assert_output 'running-closure probe failed'

# --check does not create PRs or perform git mutations
run_case normal 0 --check --only vidbox
reject_log 'gh pr'
reject_log 'git switch'

# ---------------------------------------------------------------------------
# HostKeyAlias, SSH strictness, and --repo
# ---------------------------------------------------------------------------
run_case normal 0 --prefetch-only --only nixpi4-bare
assert_log 'HostKeyAlias=nixpi4-bare'
assert_log 'StrictHostKeyChecking=yes'
assert_log "ssh .*$TEST_CLOSURE"
assert_output 'prefetched'
reject_log 'deploy '

# --repo override is respected for host enumeration.
run_case normal 0 --check --repo "$test_dir/repo" --only vidbox
assert_log "git -C $test_dir/repo"

# ---------------------------------------------------------------------------
# Prefetch-only
# ---------------------------------------------------------------------------
run_case normal 0 --prefetch-only --only vidbox
assert_output 'prefetched'

run_case prefetch-fail 1 --prefetch-only --only vidbox
assert_output 'prefetch failed'

run_case prefetch-fail-first 1
assert_output 'prefetch failed'
assert_output 'proxy.*already current and healthy'

# ---------------------------------------------------------------------------
# Activation — no reboot needed
# ---------------------------------------------------------------------------
run_case activate-ok 0 --only vidbox
assert_output 'activated (no reboot needed)'
assert_output 'verified'
reject_log 'systemctl reboot'  # userspace-only change: reboot probe returns CURRENT

# Already current + persistent: no needless switch.
run_case normal 0 --only vidbox
assert_output 'already current and healthy'
[[ ! -f "$TEST_LOG.activated" ]]

# Already current but unhealthy
run_case units-failed 1 --only vidbox
assert_output 'health check failed'

# Persistent profile update failure: host is skipped, run exits nonzero
run_case profile-fail 1 --only vidbox
assert_output 'activation failed'

# Activation failure: host is skipped, later hosts continue (per-host not die)
run_case activate-fail 1 --only vidbox
assert_output 'activation failed'

# ---------------------------------------------------------------------------
# Activation — reboot path
# ---------------------------------------------------------------------------
run_case reboot-needed 0 --only vidbox
assert_output 'activated and rebooted'
assert_output 'verified'
assert_log 'systemctl reboot'

# Host doesn't come back after reboot → incomplete nonzero
run_case reboot-timeout 1 --only vidbox
assert_output 'did not return with a changed boot ID'
reject_log 'verified'

# Boot ID never changes (same UUID every poll) → timeout failure
run_case reboot-bad-bootid 1 --only vidbox
assert_output 'changed boot ID'
run_case reboot-invalid-bootid 1 --only vidbox
assert_output 'changed boot ID'
run_case reboot-refused 1 --only vidbox
assert_output 'reboot request failed'
reject_log 'waiting for reboot'
run_case reboot-delayed 0 --only vidbox
[[ -f "$TEST_LOG.old-boot-observed" ]]
assert_output 'activated and rebooted'

# ---------------------------------------------------------------------------
# nixos-upgrade.service collision
# ---------------------------------------------------------------------------
run_case upgrade-active 1 --only vidbox
assert_output 'nixos-upgrade.service is active'
# Run continues: the host is incomplete but others would proceed.
# (With --only vidbox, only that host is selected; it's skipped → nonzero.)

# ---------------------------------------------------------------------------
# Samba: informational-only, no prompt, activation proceeds
# ---------------------------------------------------------------------------
run_case samba-active 0 --only raspberrytimemachine
assert_output 'Time Machine session'
assert_output 'proceeding anyway'
assert_output 'activated'

# ---------------------------------------------------------------------------
# --no-update deprecated alias: proceed normally
# ---------------------------------------------------------------------------
run_case normal 0 --prefetch-only --only vidbox --no-update
assert_output 'WARNING.*no-update.*deprecated'
assert_output 'prefetched'

# Override the launcher default even when invoked from an unrelated directory.
run_case normal 0 --check --repo "$test_dir/repo" --only vidbox
assert_log "git -C $test_dir/repo"

# ---------------------------------------------------------------------------
# Linked worktree: nix evaluates from the correct checkout path
# ---------------------------------------------------------------------------
"$TEST_REAL_GIT" init -q "$test_dir/main-checkout"
printf '{}\n' >"$test_dir/main-checkout/flake.nix"
"$TEST_REAL_GIT" -C "$test_dir/main-checkout" add flake.nix
"$TEST_REAL_GIT" -C "$test_dir/main-checkout" -c user.name=Fixture -c user.email=fixture@example.invalid \
  -c core.hooksPath=/dev/null -c commit.gpgsign=false commit -qm \
  $'Fixture\n\nCo-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
export TEST_LINKED_CHECKOUT="$test_dir/linked-checkout"
"$TEST_REAL_GIT" -C "$test_dir/main-checkout" -c core.hooksPath=/dev/null \
  worktree add -q --detach "$TEST_LINKED_CHECKOUT"
run_case linked-worktree 0 --check --repo "$TEST_LINKED_CHECKOUT" --only vidbox
assert_output 'already current'

# ---------------------------------------------------------------------------
# Remote probe body execution: ensure failures are never silently swallowed
# ---------------------------------------------------------------------------
awk '/<<.REMOTE_SAMBA./ {body=1; next} /^REMOTE_SAMBA$/ {exit} body {print}' \
  "$implementation" >"$test_dir/samba-probe"
awk '/<<.REMOTE_HEALTH./ {body=1; next} /^REMOTE_HEALTH$/ {exit} body {print}' \
  "$implementation" >"$test_dir/health-probe"
[[ -s "$test_dir/samba-probe" && -s "$test_dir/health-probe" ]]
export TEST_SCENARIO=normal
[[ "$(bash "$test_dir/samba-probe")" == OK:0 ]]
export TEST_SCENARIO=samba-active
[[ "$(bash "$test_dir/samba-probe")" == OK:1 ]]
for scenario in sudo-fail samba-fail; do
  export TEST_SCENARIO="$scenario"
  if bash "$test_dir/samba-probe" >"$test_dir/probe-output"; then
    echo "Samba failure was treated as success: $scenario" >&2; exit 1
  fi
  [[ ! -s "$test_dir/probe-output" ]]
done
export TEST_SCENARIO=normal
[[ "$(bash "$test_dir/health-probe")" == HEALTHY ]]
for scenario in systemctl-fail units-failed; do
  export TEST_SCENARIO="$scenario"
  if bash "$test_dir/health-probe" >"$test_dir/probe-output" 2>/dev/null; then
    echo "Health failure was treated as success: $scenario" >&2; exit 1
  fi
  [[ ! -s "$test_dir/probe-output" ]]
done

# ---------------------------------------------------------------------------
# Verify manifest headSha tracking (run_id+sha logged via gh run list)
# ---------------------------------------------------------------------------
run_case normal 0 --check --only vidbox
assert_log "gh run list"
assert_log "gh run download 42"
assert_output "${TEST_COMMIT:0:12}"

# ---------------------------------------------------------------------------
# Activation — reboot probe failure: per-host skip+continue, not die
# ---------------------------------------------------------------------------
run_case reboot-probe-fail 1 --only vidbox
assert_output 'reboot probe failed'
assert_output 'cannot determine'

# ---------------------------------------------------------------------------
# Multi-host: first host's reboot probe fails; later hosts still attempted;
# proxy (last in FLEET) must be reached.  This asserts per-host skip+continue.
# ---------------------------------------------------------------------------
run_case reboot-probe-fail-first 1
assert_output 'reboot probe failed'
assert_output 'proxy.*already current and healthy'

# ---------------------------------------------------------------------------
# Already current but pending reboot from a prior switch
# (profile == new_path, but booted kernel/initrd/modules differ)
# ---------------------------------------------------------------------------
run_case already-current-reboot-needed 0 --only vidbox
assert_output 'boot change pending'
assert_output 'verified'
assert_log 'systemctl reboot'

# ---------------------------------------------------------------------------
# REMOTE_REBOOT_CHECK body: kernel/initrd/modules comparison logic
# ---------------------------------------------------------------------------
awk '/<<.REMOTE_REBOOT_CHECK./ {body=1; next} /^REMOTE_REBOOT_CHECK$/ {exit} body {print}' \
  "$implementation" >"$test_dir/reboot-probe"
[[ -s "$test_dir/reboot-probe" ]]

# readlink mock: booted has different kernel/initrd/modules than new → REBOOT
printf '#!%s\n' "$bash_bin" >"$test_dir/bin/readlink"
cat >>"$test_dir/bin/readlink" <<'READLINK_DIFF'
case "$2" in
  /run/booted-system/kernel)         echo /nix/store/kernel-old ;;
  /run/booted-system/initrd)         echo /nix/store/initrd-old ;;
  /run/booted-system/kernel-modules) echo /nix/store/modules-old ;;
  */kernel)                          echo /nix/store/kernel-new ;;
  */initrd)                          echo /nix/store/initrd-new ;;
  */kernel-modules)                  echo /nix/store/modules-new ;;
  *) exit 1 ;;
esac
READLINK_DIFF
chmod +x "$test_dir/bin/readlink"
[[ "$(bash "$test_dir/reboot-probe" /nix/store/aaa-nixos-system-test)" == REBOOT ]]

# readlink mock: booted identical to new → CURRENT (userspace-only change)
printf '#!%s\n' "$bash_bin" >"$test_dir/bin/readlink"
cat >>"$test_dir/bin/readlink" <<'READLINK_SAME'
case "$2" in
  /run/booted-system/kernel)         echo /nix/store/kernel-same ;;
  /run/booted-system/initrd)         echo /nix/store/initrd-same ;;
  /run/booted-system/kernel-modules) echo /nix/store/modules-same ;;
  */kernel)                          echo /nix/store/kernel-same ;;
  */initrd)                          echo /nix/store/initrd-same ;;
  */kernel-modules)                  echo /nix/store/modules-same ;;
  *) exit 1 ;;
esac
READLINK_SAME
chmod +x "$test_dir/bin/readlink"
[[ "$(bash "$test_dir/reboot-probe" /nix/store/aaa-nixos-system-test)" == CURRENT ]]

# readlink failure → ERR: output and non-zero exit (no silent swallow)
printf '#!%s\n' "$bash_bin" >"$test_dir/bin/readlink"
cat >>"$test_dir/bin/readlink" <<'READLINK_FAIL'
exit 1
READLINK_FAIL
chmod +x "$test_dir/bin/readlink"
if bash "$test_dir/reboot-probe" /nix/store/aaa-nixos-system-test \
    >"$test_dir/probe-output" 2>/dev/null; then
  echo "Reboot probe readlink failure was treated as success" >&2; exit 1
fi
grep -q 'ERR:' "$test_dir/probe-output"
rm -f "$test_dir/bin/readlink"

# readlink -e (not -f): a path that does not exist must not be treated as present.
# The probe body now uses -e; verify the distinction by having readlink succeed
# only for existing paths (exit 0 returns path) and fail for missing paths
# (exit 1, which must cause ERR: output and non-zero exit from the probe body).
printf '#!%s\n' "$bash_bin" >"$test_dir/bin/readlink"
cat >>"$test_dir/bin/readlink" <<'READLINK_E'
# Simulate -e semantics: /run/booted-system/* paths exist; new system paths do not.
case "$2" in
  /run/booted-system/kernel)         echo /nix/store/kernel-old ;;
  /run/booted-system/initrd)         echo /nix/store/initrd-old ;;
  /run/booted-system/kernel-modules) echo /nix/store/modules-old ;;
  */kernel|*/initrd|*/kernel-modules) exit 1 ;;  # missing → fail
  *) exit 1 ;;
esac
READLINK_E
chmod +x "$test_dir/bin/readlink"
if bash "$test_dir/reboot-probe" /nix/store/missing-nixos-system-test \
    >"$test_dir/probe-output" 2>/dev/null; then
  echo "Reboot probe succeeded with missing new-system boot artifact" >&2; exit 1
fi
grep -q 'ERR:new-' "$test_dir/probe-output"
rm -f "$test_dir/bin/readlink"

# ---------------------------------------------------------------------------
# REMOTE_ACTIVATE body: upgrade guard, profile set, and switch-to-configuration
# ---------------------------------------------------------------------------
awk '/<<.REMOTE_ACTIVATE./ {body=1; next} /^REMOTE_ACTIVATE$/ {exit} body {print}' \
  "$implementation" >"$test_dir/activate-body"
[[ -s "$test_dir/activate-body" ]]

# Create a fake switch-to-configuration alongside a fixture store path
mkdir -p "$test_dir/store/aaa-nixos-system-fixture/bin"
printf '#!%s\n' "$bash_bin" >"$test_dir/store/aaa-nixos-system-fixture/bin/switch-to-configuration"
cat >>"$test_dir/store/aaa-nixos-system-fixture/bin/switch-to-configuration" <<'STC'
[[ "$1" == switch ]] || exit 99
printf 'activating the configuration...\n'
printf 'installing bootloader...\n' >&2
touch "$TEST_LOG.bootloader-installed"
STC
chmod +x "$test_dir/store/aaa-nixos-system-fixture/bin/switch-to-configuration"
stc_path="$test_dir/store/aaa-nixos-system-fixture"
export TEST_BODY_SYSTEM="$stc_path"
ln -s mock "$test_dir/bin/readlink"

# Normal activation: inactive upgrade service → profile set → ACTIVATED
export TEST_SCENARIO=normal
out="$(bash "$test_dir/activate-body" \
  "$stc_path" "https://cachix-dummy" "dummy-key" "https://upstream-dummy" "upstream-key")"
[[ "$out" == ACTIVATED ]] \
  || { printf 'FAIL REMOTE_ACTIVATE body: expected ACTIVATED, got: %s\n' "$out" >&2; exit 1; }
[[ -f "$TEST_LOG.bootloader-installed" ]]

# A test-only activation must install the bootloader as well as update the profile.
export TEST_SCENARIO=body-test
rm -f "$TEST_LOG.bootloader-installed"
[[ "$(bash "$test_dir/activate-body" "$stc_path")" == ACTIVATED ]]
[[ -f "$TEST_LOG.bootloader-installed" ]]
export TEST_SCENARIO=body-current
rm -f "$TEST_LOG.bootloader-installed"
[[ "$(bash "$test_dir/activate-body" "$stc_path")" == CURRENT ]]
[[ ! -f "$TEST_LOG.bootloader-installed" ]]
export TEST_SCENARIO=body-read-fail
if bash "$test_dir/activate-body" "$stc_path"; then
  echo 'Missing persistent profile treated as current' >&2; exit 1
fi

# nixos-upgrade active: body must output UPGRADE_ACTIVE and exit 0 (no switch)
export TEST_SCENARIO=upgrade-active
out="$(bash "$test_dir/activate-body" \
  "$stc_path" "https://cachix-dummy" "dummy-key" "https://upstream-dummy" "upstream-key")"
[[ "$out" == UPGRADE_ACTIVE:active ]] \
  || { printf 'FAIL REMOTE_ACTIVATE body upgrade-active: got: %s\n' "$out" >&2; exit 1; }

# nix-env failure → body must exit non-zero (no silent swallow)
export TEST_SCENARIO=activate-fail
if bash "$test_dir/activate-body" \
    "$stc_path" "https://c" "k" "https://u" "uk" >"$test_dir/probe-output" 2>/dev/null; then
  echo "REMOTE_ACTIVATE body succeeded despite nix-env failure" >&2; exit 1
fi

# ---------------------------------------------------------------------------
# REMOTE_FETCH body: nix-store --realise with substituters and no local builds
# ---------------------------------------------------------------------------
awk '/<<.REMOTE_FETCH./ {body=1; next} /^REMOTE_FETCH$/ {exit} body {print}' \
  "$implementation" >"$test_dir/fetch-body"
[[ -s "$test_dir/fetch-body" ]]

# nix-store success: body must exit 0 with correct flags logged
export TEST_SCENARIO=normal
: >"$TEST_LOG"
bash "$test_dir/fetch-body" \
  "/nix/store/aaa-fixture" "https://cachix" "cachix-key" "https://upstream" "upstream-key" \
  >"$test_dir/probe-output" 2>&1 || {
  echo "REMOTE_FETCH body exited nonzero on success" >&2
  cat "$test_dir/probe-output" >&2; exit 1
}
# The body uses 'exec nix-store --realise' so it replaces the shell; check log
grep -q 'nix-store.*--realise' "$test_dir/probe-output" \
  || grep -q 'nix-store.*--realise' "$TEST_LOG" \
  || grep -q 'nix-store' "$TEST_LOG"
assert_log 'nix-store.*--max-jobs 0 --builders .*--option substituters https://cachix https://upstream'
assert_log 'nix-store.*--option require-sigs true --option fallback false'

# nix-store failure → body must exit non-zero
export TEST_SCENARIO=activate-fail  # reuses same nix-store fail case
if bash "$test_dir/fetch-body" \
    "/nix/store/aaa-fixture" "https://c" "ck" "https://u" "uk" \
    >"$test_dir/probe-output" 2>/dev/null; then
  echo "REMOTE_FETCH body succeeded despite nix-store failure" >&2; exit 1
fi

# Exercise the actual CI producer, not a second implementation of its manifest format.
awk '
  /- name: Merge path fragments into combined manifest/ {step=1; next}
  step && /run: \|/ {body=1; next}
  body && /^          / {sub(/^          /, ""); print; next}
  body {exit}
' "$workflow" >"$test_dir/collect-paths"
[[ -s "$test_dir/collect-paths" ]]
mkdir "$test_dir/fragments"
export GITHUB_SHA="$TEST_COMMIT"
for spec in 'x86|vidbox' 'nixpi4|nixpi4-bare' 'nixpi5|nixpi5' 'arm64|proxy raspberrytimemachine'; do
  jq -n --arg sha "$TEST_COMMIT" --arg hosts "${spec#*|}" --arg path "$TEST_CLOSURE" \
    '{headSha: $sha, paths: ($hosts | split(" ") | map({key: ., value: $path}) | from_entries)}' \
    >"$test_dir/fragments/host-paths-${spec%%|*}.json"
done
(cd "$test_dir/fragments" && bash "$test_dir/collect-paths") >"$test_dir/manifest-output"
jq -e --arg sha "$TEST_COMMIT" --arg path "$TEST_CLOSURE" \
  '.headSha == $sha and (.paths | length == 5 and all(.[]; . == $path))' \
  "$test_dir/fragments/fleet-host-paths.json" >/dev/null
for invalid in \
  '{"headSha":"wrong","paths":{}}' \
  "{\"headSha\":\"$TEST_COMMIT\",\"paths\":{\"vidbox\":\"/tmp/not-a-system\"}}" \
  "{\"headSha\":\"$TEST_COMMIT\",\"paths\":{\"other\":\"$TEST_CLOSURE\"}}"; do
  printf '%s\n' "$invalid" >"$test_dir/fragments/host-paths-x86.json"
  if (cd "$test_dir/fragments" && bash "$test_dir/collect-paths") >"$test_dir/manifest-output" 2>&1; then
    echo 'CI published invalid fleet paths' >&2; exit 1
  fi
done

printf 'Fleet regression tests passed.\n'
