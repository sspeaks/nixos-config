#!/usr/bin/env bash
set -euo pipefail

implementation="$(realpath "${1:-scripts/update-fleet.sh}")"
tty_runner="$(dirname "$(realpath "$0")")/with-tty.py"
export TEST_REAL_GIT
TEST_REAL_GIT="$(command -v git)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -p "$test_dir/bin" "$test_dir/repo"
printf '{}\n' > "$test_dir/repo/flake.nix"
export FLEET_DEFAULT_REPO="$test_dir/repo"
export FLEET_DEPLOY="$test_dir/bin/deploy"
export TEST_LOG="$test_dir/commands"
export TEST_CLOSURE="/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-nixos-system-fixture"
export TEST_COMMIT="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
export TEST_SCENARIO=normal

printf '#!%s\n' "$(command -v bash)" >"$test_dir/bin/mock"
cat >>"$test_dir/bin/mock" <<'MOCK'
set -euo pipefail
cmd="${0##*/}"
printf '%s %s\n' "$cmd" "$*" >> "$TEST_LOG"
case "$cmd" in
  timeout) shift; exec "$@" ;;
  sleep) exit 0 ;;
  sudo)
    [[ "$TEST_SCENARIO" != sudo-fail && "$TEST_SCENARIO" != samba-unknown ]] || exit 1
    [[ "$1" != -n ]] || shift
    exec "$@" ;;
  smbstatus)
    case "$TEST_SCENARIO" in
      samba-fail) exit 1 ;;
      samba-active|samba-decline) printf '123 timemachine connected\n' ;;
      *) printf 'PID Username Group Machine\n' ;;
    esac ;;
  systemctl)
    case "$TEST_SCENARIO" in
      systemctl-fail) exit 1 ;;
      units-failed) echo 'fixture.service loaded failed failed Fixture' ;;
      *) exit 0 ;;
    esac ;;
  git)
    if [[ "$TEST_SCENARIO" == linked-worktree ]]; then exec "$TEST_REAL_GIT" "$@"; fi
    case " $* " in
      *" --is-inside-work-tree "*) echo true ;;
      *" status --porcelain "*) [[ "$TEST_SCENARIO" != dirty ]] || echo ' M flake.nix' ;;
      *" rev-parse "*)
        if [[ "$TEST_SCENARIO" == drift && -e "$TEST_LOG.drift" ]]; then echo bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
        else echo "$TEST_COMMIT"; fi ;;
      *" diff --quiet "*) [[ "$TEST_SCENARIO" == unchanged ]] ;;
      *" fetch "*) [[ "$TEST_SCENARIO" != fetch-fail ]] ;;
      *" merge-base "*) exit 0 ;;
      *" switch "*|*" add "*|*" commit "*|*" push "*) exit 0 ;;
      *) echo "Unexpected git invocation: $*" >&2; exit 97 ;;
    esac ;;
  nix)
    if [[ "$TEST_SCENARIO" == linked-worktree && "$PWD" != "$TEST_LINKED_CHECKOUT" ]]; then
      echo 'Evaluated the wrong checkout' >&2; exit 97
    fi
    case " $* " in
      *" builtins.attrNames "*)
        if [[ "$TEST_SCENARIO" == host-extra ]]; then
          printf '["raspberrytimemachine","vidbox","nixpi4-bare","nixpi5","proxy","vm","future-host"]\n'
        else printf '["raspberrytimemachine","vidbox","nixpi4-bare","nixpi5","proxy"]\n'; fi ;;
      *" eval "*)
        if [[ "$TEST_SCENARIO" == eval-fail ]]; then echo 'evaluation unavailable' >&2; exit 1; fi
        echo "$TEST_CLOSURE" ;;
      *" path-info "*)
        [[ "$TEST_SCENARIO" != cache-fail ]] || exit 1
        [[ "$TEST_SCENARIO" != drift ]] || touch "$TEST_LOG.drift"
        echo "$TEST_CLOSURE" ;;
      *" flake update "*) exit 0 ;;
      *) echo "Unexpected nix invocation: $*" >&2; exit 97 ;;
    esac ;;
  ssh)
    if [[ "$TEST_SCENARIO" == unreachable || ( "$TEST_SCENARIO" == partial && "$*" == *192.168.5.195* ) ]]; then
      echo 'SSH connection failed' >&2; exit 255
    fi
    case "$*" in
      *hostname*) echo fixture ;;
      *readlink*)
        [[ "$TEST_SCENARIO" != running-fail ]] || exit 255
        if [[ "$TEST_SCENARIO" == outdated || "$TEST_SCENARIO" == activate-fail ||
              "$TEST_SCENARIO" == samba-decline || "$TEST_SCENARIO" == samba-unknown ||
              ( "$TEST_SCENARIO" == activate-ok && ! -e "$TEST_LOG.activated" ) ]]; then
          echo /nix/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-nixos-system-old
        else echo "$TEST_CLOSURE"; fi ;;
      *"/bash -s"*) exec bash -s ;;
      *) echo "Unexpected SSH invocation: $*" >&2; exit 97 ;;
    esac ;;
  deploy)
    [[ "$TEST_SCENARIO" != prefetch-fail ]] || exit 1
    [[ "$TEST_SCENARIO" != activate-fail || "$*" != *--test* ]] || exit 1
    if [[ "$TEST_SCENARIO" == activate-ok && "$*" == *--test* ]]; then touch "$TEST_LOG.activated"; fi ;;
  gh)
    case "$*" in
      "auth status") [[ "$TEST_SCENARIO" != auth-fail ]] ;;
      "pr create "*) echo https://github.com/example/repo/pull/123 ;;
      "pr view "*"--json headRefOid"*)
        if [[ "$TEST_SCENARIO" == wrong-head ]]; then echo bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
        else echo "$TEST_COMMIT"; fi ;;
      "pr checks "*)
        case "$TEST_SCENARIO" in
          checks-fail) echo '[{"name":"check","bucket":"fail","workflow":"Flake Check"}]'; exit 1 ;;
          checks-missing) echo '[]'; exit 1 ;;
          checks-pending) echo '[{"name":"check","bucket":"pending","workflow":"Flake Check"}]'; exit 8 ;;
          checks-wrong-workflow) echo '[{"name":"check","bucket":"pass","workflow":"Other Workflow"}]' ;;
          checks-api) echo 'API error' >&2; exit 1 ;;
          *) echo '[{"name":"check","bucket":"pass","workflow":"Flake Check"}]' ;;
        esac ;;
      "pr merge "*)
        [[ "$*" == *"--match-head-commit $TEST_COMMIT"* ]] || exit 97 ;;
      "pr view "*"--json state,mergeCommit"*)
        printf '{"state":"MERGED","mergeCommit":{"oid":"%s"}}\n' "$TEST_COMMIT" ;;
      "run list "*)
        case "$TEST_SCENARIO" in
          build-fail) conclusion=failure ;;
          *) conclusion=success ;;
        esac
        sha="$TEST_COMMIT"
        [[ "$TEST_SCENARIO" != wrong-build ]] || sha=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
        if [[ "$TEST_SCENARIO" == build-missing ]]; then echo '[]'
        else printf '[{"databaseId":1,"status":"completed","conclusion":"%s","headSha":"%s"}]\n' "$conclusion" "$sha"; fi ;;
      *) echo "Unexpected gh invocation: $*" >&2; exit 97 ;;
    esac ;;
esac
MOCK
chmod +x "$test_dir/bin/mock"
for cmd in git nix ssh gh timeout sleep deploy sudo smbstatus systemctl; do ln -s mock "$test_dir/bin/$cmd"; done
export PATH="$test_dir/bin:$PATH"

run_case() {
  local scenario="$1" expected="$2"
  shift 2
  export TEST_SCENARIO="$scenario"
  : >"$TEST_LOG"
  rm -f "$TEST_LOG.drift" "$TEST_LOG.activated"
  local status=0
  if [[ "${TEST_WITH_TTY:-false}" == true ]]; then
    python3 "$tty_runner" bash "$implementation" "$@" >"$test_dir/output" 2>&1 || status=$?
  else
    bash "$implementation" "$@" >"$test_dir/output" 2>&1 || status=$?
  fi
  if [[ "$status" != "$expected" ]]; then
    printf 'FAIL %s: wanted %s, got %s\n' "$scenario" "$expected" "$status" >&2
    cat "$test_dir/output" >&2
    exit 1
  fi
}
assert_output() { grep -q -- "$1" "$test_dir/output" || { cat "$test_dir/output" >&2; exit 1; }; }
assert_log() { grep -q -- "$1" "$TEST_LOG" || { cat "$TEST_LOG" >&2; exit 1; }; }
reject_log() { if grep -q -- "$1" "$TEST_LOG"; then cat "$TEST_LOG" >&2; exit 1; fi; }

run_case normal 0 --help
reject_log 'gh '
run_case normal 1 --check --only vidbox --only typo
assert_output 'unknown fleet host: typo'
reject_log 'ssh '
run_case normal 1 --check --prefetch-only
run_case normal 1 --check --auto-merge
run_case normal 0 --check --only vidbox --only vidbox
assert_output 'already current'
reject_log 'gh '
reject_log 'deploy '
run_case dirty 0 --check --only vidbox
run_case host-extra 0 --check --only vidbox
assert_output 'Not fleet-managed: vm (scratch VM)'
assert_output 'WARNING: unmanaged configuration: future-host'
run_case dirty 1 --no-update --prefetch-only --only vidbox
reject_log 'ssh '
run_case outdated 0 --check --only vidbox
assert_output 'update available'
run_case partial 1 --check --only vidbox --only nixpi5
assert_output 'unreachable'
assert_output 'already current'
run_case running-fail 1 --check --only vidbox
assert_output 'running-closure probe failed'
run_case eval-fail 1 --check --only vidbox
run_case cache-fail 1 --check --only vidbox
run_case unreachable 1 --check --only vidbox
run_case drift 1 --check --only vidbox
assert_output 'checkout changed'
run_case normal 0 --no-update --prefetch-only --only nixpi4-bare
reject_log 'gh '
assert_log 'HostKeyAlias=nixpi4-bare'
assert_log 'StrictHostKeyChecking=yes'
assert_log "deploy .*--expected-commit $TEST_COMMIT"
assert_log "deploy .*--expected-system-path $TEST_CLOSURE"
assert_log 'deploy .*--host-key-alias nixpi4-bare'
assert_output 'prefetched'
run_case prefetch-fail 1 --no-update --prefetch-only --only vidbox
assert_output 'no hosts activated'
run_case fetch-fail 1 --prefetch-only --auto-merge --only vidbox
reject_log 'flake update'
run_case auth-fail 1 --prefetch-only --auto-merge --only vidbox
reject_log 'flake update'
run_case unchanged 0 --prefetch-only --auto-merge --only vidbox
reject_log 'gh pr create'
for scenario in wrong-head checks-fail checks-missing checks-pending checks-api checks-wrong-workflow; do
  run_case "$scenario" 1 --prefetch-only --auto-merge --only vidbox
  reject_log 'gh pr merge'
done
for scenario in build-fail wrong-build build-missing; do
  run_case "$scenario" 1 --prefetch-only --auto-merge --only vidbox
  reject_log 'deploy '
done
run_case normal 0 --prefetch-only --auto-merge --only vidbox
assert_log "gh run list .*--commit $TEST_COMMIT"
assert_log "git switch --detach $TEST_COMMIT"
assert_output 'prefetched'

export TEST_WITH_TTY=true
run_case normal 0 --no-update --only vidbox
assert_output 'already current and healthy'
reject_log 'deploy .*--test'
run_case units-failed 1 --no-update --only vidbox --only nixpi5
assert_output 'already current but health check failed'
reject_log 'deploy .*--test'
run_case activate-fail 1 --no-update --only vidbox --only nixpi5
assert_output 'stopping before later hosts'
assert_log 'deploy .*--test vidbox'
reject_log 'deploy .*--test nixpi5'
run_case activate-ok 0 --no-update --only vidbox
assert_output 'test activated and confirmed'
assert_output "To promote manually: $FLEET_DEPLOY"
ln -s "$FLEET_DEPLOY" "$test_dir/repo/deploy"
run_case activate-ok 0 --no-update --only vidbox
assert_output "To promote manually: $test_dir/repo/deploy"
export TEST_TTY_INPUT=$'no\n'
run_case samba-decline 1 --no-update --only raspberrytimemachine
assert_output 'activation declined'
reject_log 'deploy .*--test'
run_case samba-unknown 1 --no-update --only raspberrytimemachine
assert_output 'Time Machine sessions: unknown'
assert_output 'activation declined'
reject_log 'deploy .*--test'
unset TEST_TTY_INPUT TEST_WITH_TTY

# Override the launcher default even when invoked from an unrelated directory.
run_case normal 0 --check --repo "$test_dir/repo" --only vidbox
assert_log "git -C $test_dir/repo"

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

# Execute the actual remote probe bodies with failing commands, not copies of
# their logic. A failed producer must not yield a success-shaped sentinel.
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
printf 'Fleet regression tests passed.\n'
