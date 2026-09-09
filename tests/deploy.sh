#!/usr/bin/env bash
# All Git, Nix, SSH and remote commands are local mocks. Python supplies a PTY.
set -euo pipefail
implementation="${1:-${BASH_SOURCE[0]%/*}/../scripts/deploy.sh}"
implementation="$(cd "$(dirname "$implementation")" && pwd)/$(basename "$implementation")"
[[ -f "$implementation" ]] || { echo "Missing implementation: $implementation" >&2; exit 1; }
work="$(mktemp -d "${TMPDIR:-/tmp}/deploy-tests.XXXXXXXX")"
trap 'rm -rf -- "$work"' EXIT
trap 'exit 1' HUP INT TERM
printf '#!%s\n' "$(command -v python3)" > "$work/driver.py"
cat >> "$work/driver.py" <<'PYTHON'
import errno
import json
import os
from pathlib import Path
import pty
import select
import shlex
import subprocess
import sys
import time

COMMIT = "a" * 40
NEW = "/nix/store/" + "1" * 32 + "-nixos-system-nixpi5-test"
OLD = "/nix/store/" + "2" * 32 + "-nixos-system-nixpi5-old"
PREFIX = "nixos-laptop-deploy-rollback-guard"


def mock():
    command = Path(sys.argv[0]).name
    args = sys.argv[1:]
    root = Path(os.environ["MOCK_ROOT"])
    state_file = root / "state.json"
    state = json.loads(state_file.read_text())
    scenario = state["scenario"]
    phase = state.get("phase", "")

    def save():
        state_file.write_text(json.dumps(state))

    def event(name):
        state["events"].append(name)
        save()

    def mapped(path):
        return str(root / "remote") + path

    def fail(message):
        print(message, file=sys.stderr)
        return 1

    if command == "timeout":
        return subprocess.call(args[2:])
    if command == "sleep":
        return 0
    if command == "git":
        args = args[2:]  # -C checkout
        if args[0] == "status":
            if scenario == "status_failure":
                return fail("mock git status failed")
            if scenario == "dirty":
                print(" M flake.nix")
        elif args[0] == "rev-parse":
            if "--is-inside-work-tree" in args:
                print("true")
            else:
                state["rev_count"] = state.get("rev_count", 0) + 1
                save()
                drift = scenario == "checkout_drift" and state["rev_count"] >= 5
                print("b" * 40 if drift else COMMIT)
        elif args[0] == "fetch":
            event("git-fetch")
            if scenario == "fetch_failure":
                return fail("mock fetch failed")
        elif args[0] == "merge-base":
            if scenario == "unreviewed":
                return 1
        else:
            return fail("unexpected git command " + repr(args))
        return 0
    if command == "nix":
        if "eval" in args:
            assert "--read-only" in args and "--no-write-lock-file" in args
            if scenario == "eval_failure":
                return fail("mock evaluation failed")
            print("aarch64-linux" if "hostPlatform" in args[-1] else NEW)
        elif "path-info" in args:
            assert "--store" in args and "require-sigs" in args
            assert "sspeaks-nix.cachix.org-1:" in " ".join(args)
            if scenario == "cache_failure":
                return fail("mock cache/signature failure")
        else:
            return fail("unexpected nix command " + repr(args))
        return 0
    if command == "ssh":
        opts = []
        while args and args[0] == "-o":
            opts.append(args[1])
            args = args[2:]
        for required in ("BatchMode=yes", "StrictHostKeyChecking=yes",
                         "ControlMaster=no", "ControlPath=none"):
            assert required in opts, (required, opts)
        if state["alias"]:
            assert "HostKeyAlias=nixpi5" in opts, opts
        else:
            assert not any(x.startswith("HostKeyAlias=") for x in opts)
        assert args[0] == "nixpi5-lan", args
        remote_command = " ".join(args[1:])
        event("ssh")
        if remote_command == "uname -m":
            print("x86_64" if scenario == "wrong_arch" else "aarch64")
            return 0
        if "diff-closures" in remote_command:
            event("diff")
            return 1 if scenario == "diff_failure" else 0
        if "is-active --quiet" in remote_command:
            event("fresh-ssh")
            return 1 if scenario == "fresh_failure" else 0
        assert "bash -s" in remote_command, remote_command
        script = sys.stdin.read()
        if "REMOTE ERROR" in script and "service_idle()" in script:
            phase = "disarm"
        elif "systemd-run --quiet" in script:
            phase = "activation"
        elif "exec /run/current-system/sw/bin/nix-store" in script:
            phase = "substitute"
        elif "Missing remote prerequisite" in script:
            phase = "preflight"
        elif 'expected_system="$1"' in script:
            phase = "health"
        else:
            return fail("unrecognized remote script")
        state["phase"] = phase
        event(phase)
        marker = Path(mapped("/run/" + PREFIX + ".armed"))
        if phase == "preflight" and scenario in ("sudo_failure", "tool_failure"):
            return fail("mock passwordless sudo / remote prerequisite failure")
        if phase == "health" and scenario in ("health_empty", "health_malformed", "health_status_failure"):
            if scenario != "health_empty":
                print("DEPLOY_HEALTH_OK" if scenario == "health_status_failure" else "unexpected")
            return 1 if scenario == "health_status_failure" else 0
        if phase == "disarm":
            if scenario == "wrong_marker":
                marker.write_text("different-deployment\n")
            if scenario == "missing_marker":
                marker.unlink()
            if scenario == "symlink_marker":
                marker.unlink()
                other = marker.with_suffix(".other")
                other.write_text("other\n")
                marker.symlink_to(other)
        # Execute the real remote Bash bodies, but remap every remote absolute
        # path into this private fixture. Never invoke sudo or a real system tool.
        for old in ("/run/", "/nix/"):
            script = script.replace(old, mapped(old))
            remote_command = remote_command.replace(old, mapped(old))
        script = script.replace('[[ "$EUID" == 0 ]]', "[[ 0 == 0 ]]")
        argv = shlex.split(remote_command)
        remote_args = argv[argv.index("--") + 1:] if "--" in argv else []
        return subprocess.run(["bash", "-s", "--", *remote_args],
                              input=script, text=True).returncode
    if command == "readlink":
        if args[-1].endswith("/nix/var/nix/profiles/system"):
            print(mapped(OLD))
        else:
            wrong = (phase == "health" and scenario == "wrong_closure") or (
                phase == "disarm" and scenario == "closure_recheck")
            print(mapped(OLD if wrong else NEW))
        return 0
    if command == "stat":
        print("1000" if scenario == "wrong_owner" else "0")
        return 0
    if command == "flock":
        if phase == "disarm" and scenario == "rollback_lock":
            return 1
        state["locked"] = "-u" not in args
        save()
        return 0
    if command == "systemd-run":
        event("arm")
        assert "--service-type=oneshot" in args
        callback = args[args.index("-c") + 1]
        assert "flock" in callback and "rolling-back" in callback
        assert "--profile /nix/var/nix/profiles/system".replace(
            "/nix/", mapped("/nix/")) in callback
        state["timer"] = "active"
        save()
        return 1 if scenario == "arm_failure" else 0
    if command == "nix-store":
        event("realise")
        assert args[args.index("--max-jobs") + 1] == "0"
        assert args[args.index("--builders") + 1] == ""
        assert args[args.index("fallback") + 1] == "false"
        assert args[args.index("require-sigs") + 1] == "true"
        assert args[args.index("substituters") + 1] == (
            "https://sspeaks-nix.cachix.org https://cache.nixos.org")
        keys = args[args.index("trusted-public-keys") + 1]
        assert "sspeaks-nix.cachix.org-1:" in keys and "cache.nixos.org-1:" in keys
        return 1 if scenario == "substitute_failure" else 0
    if command == "nix-env":
        event("profile")
        assert state["timer"] == "active"
        return 0
    if command == "switch-to-configuration":
        event("activate-" + args[0])
        assert state["timer"] == "active"
        assert not state["locked"], "activation must not block the dead-man callback"
        return 1 if scenario == "activation_failure" else 0
    if command == "systemctl":
        if args[0] == "is-active":
            return 0 if state.get("timer") == "active" else 1
        if args[0] in ("stop", "start"):
            event("timer-" + args[0])
            if args[0] == "stop" and scenario == "stop_failure":
                return 1
            state["timer"] = "inactive" if args[0] == "stop" else "active"
            save()
            return 0
        if args[0] == "list-units":
            event("units-" + phase)
            if scenario == "units_failure" and phase == "health":
                return fail("mock list-units failed")
            if scenario == "units_recheck_failure" and phase == "disarm":
                return fail("mock second list-units failed")
            if scenario == "failed_units" and phase == "health":
                print("broken.service loaded failed failed broken service")
            if scenario == "malformed_units" and phase == "health":
                print("unexpected status")
            return 0
        if args[0] == "show":
            prop = args[1].split("=")[1]
            if prop == "NFailedUnits":
                event("count-" + phase)
                if scenario == "count_failure" and phase == "health":
                    return 1
                if scenario == "count_recheck_failure" and phase == "disarm":
                    return 1
                if scenario == "malformed_count" and phase == "health":
                    print("unknown")
                elif scenario == "failed_units" and phase == "health":
                    print("1")
                elif scenario == "health_recheck" and phase == "disarm":
                    print("1")
                else:
                    print("0")
                return 0
            if args[-1] == "nixos-upgrade.service":
                print("inactive")
                return 0
            if args[-1].endswith(".timer"):
                if scenario == "timer_probe_failure" and phase == "disarm":
                    return 1
                if prop == "ActiveState":
                    print("inactive" if scenario == "timer_inactive" else state["timer"])
                elif prop == "SubState":
                    print("elapsed" if scenario == "timer_elapsed" else "waiting")
                else:
                    return fail("unexpected timer property")
                return 0
            if args[-1].endswith(".service"):
                if scenario == "service_probe_failure":
                    return 1
                running = scenario == "service_running" or (
                    scenario == "service_race" and state.get("timer") == "inactive")
                if prop == "ActiveState":
                    print("activating" if running else "inactive")
                elif prop == "SubState":
                    print("start" if running else "dead")
                elif prop == "Result":
                    print("" if scenario == "service_unloaded" and state.get("timer") == "inactive"
                          else "exit-code" if scenario == "service_failed" else "success")
                else:
                    return fail("unexpected service property")
                return 0
        return fail("unexpected systemctl " + repr(args))
    if command == "rm":
        event("remove-marker")
        for arg in args:
            if arg.startswith("-"):
                continue
            assert arg.startswith(str(root) + "/remote/"), arg
            Path(arg).unlink(missing_ok="-f" in args)
        return 0
    return fail("unhandled mock " + command)


def main():
    implementation = str(Path(sys.argv[1]).resolve())
    workspace = Path(__file__).resolve().parent
    bins = workspace / "bin"
    bins.mkdir()
    for name in ("git", "nix", "ssh", "timeout", "sleep", "readlink", "stat",
                 "flock", "systemd-run", "nix-store", "nix-env", "systemctl",
                 "switch-to-configuration", "rm"):
        (bins / name).symlink_to(Path(__file__).resolve())
    scenarios = [
        "dry_run", "test", "switch", "no_alias", "service_unloaded", "wrong_commit", "wrong_path",
        "invalid_alias", "invalid_commit", "invalid_path", "missing_option",
        "status_failure", "dirty", "fetch_failure", "unreviewed", "eval_failure",
        "cache_failure", "sudo_failure", "tool_failure", "wrong_arch",
        "substitute_failure", "diff_failure", "checkout_drift", "arm_failure",
        "activation_failure", "fresh_failure", "wrong_closure", "failed_units",
        "units_failure", "count_failure", "malformed_units", "malformed_count",
        "health_empty", "health_malformed", "health_status_failure",
        "initial_eof", "initial_declined", "final_eof", "final_declined",
        "health_recheck", "closure_recheck", "count_recheck_failure",
        "units_recheck_failure", "wrong_marker", "missing_marker", "symlink_marker",
        "wrong_owner", "rollback_lock", "timer_inactive", "timer_elapsed",
        "timer_probe_failure", "service_running", "service_failed",
        "service_probe_failure", "service_race", "stop_failure",
    ]
    for scenario in scenarios:
        root = workspace / scenario
        root.mkdir()
        checkout = root / "checkout"
        checkout.mkdir()
        (checkout / "flake.nix").write_text("{}\n")
        (root / "remote/run").mkdir(parents=True)
        for closure in (NEW, OLD, "/run/current-system"):
            directory = root / ("remote" + closure + "/sw/bin")
            directory.mkdir(parents=True)
            for name in ("nix", "nix-store", "nix-env", "systemctl", "flock"):
                (directory / name).symlink_to(bins / name)
            (directory / "bash").symlink_to(os.environ["TEST_BASH"])
            activation = directory.parent.parent / "bin"
            activation.mkdir()
            (activation / "switch-to-configuration").symlink_to(
                bins / "switch-to-configuration")
        state_path = root / "state.json"
        state_path.write_text(json.dumps({
            "scenario": scenario, "events": [], "alias": scenario != "no_alias",
        }))
        args = ["bash", implementation, "--flake-dir", str(checkout),
                "--ssh-target", "nixpi5-lan"]
        if scenario != "no_alias":
            args += ["--host-key-alias", "bad alias" if scenario == "invalid_alias" else "nixpi5"]
        args += ["--expected-commit",
                 "b" * 40 if scenario == "wrong_commit" else
                 "bad" if scenario == "invalid_commit" else COMMIT]
        args += ["--expected-system-path",
                 OLD if scenario == "wrong_path" else
                 "/nix/store/bad;command" if scenario == "invalid_path" else NEW]
        if scenario == "dry_run":
            args += ["--dry-run"]
        if scenario == "switch":
            args += ["--switch"]
        args += ["nixpi5"]
        if scenario == "missing_option":
            args += ["--host-key-alias"]
        env = dict(os.environ, PATH=str(bins) + ":" + os.environ["PATH"],
                   MOCK_ROOT=str(root))
        master, slave = pty.openpty()
        process = subprocess.Popen(args, stdin=slave, stdout=slave, stderr=slave, env=env)
        os.close(slave)
        output = b""
        first_sent = final_sent = False
        deadline = time.monotonic() + 25
        while True:
            if time.monotonic() > deadline:
                process.kill()
                raise AssertionError(f"{scenario} timed out:\n{output.decode(errors='replace')}")
            ready, _, _ = select.select([master], [], [], 0.1)
            if ready:
                try:
                    data = os.read(master, 65536)
                except OSError as exc:
                    if exc.errno == errno.EIO:
                        break
                    raise
                if not data:
                    break
                output += data
            if not first_sent and b"-minute rollback guard and run '" in output:
                answer = b"\x04" if scenario == "initial_eof" else (
                    b"no\n" if scenario == "initial_declined" else b"nixpi5\n")
                os.write(master, answer)
                first_sent = True
            if not final_sent and b"to disarm rollback: " in output:
                answer = b"\x04" if scenario == "final_eof" else (
                    b"no\n" if scenario == "final_declined" else b"nixpi5\n")
                os.write(master, answer)
                final_sent = True
            if process.poll() is not None and not ready:
                break
        os.close(master)
        status = process.wait()
        text = output.decode(errors="replace")
        state = json.loads(state_path.read_text())
        events = state["events"]
        success = scenario in ("dry_run", "test", "switch", "no_alias", "service_unloaded")
        assert (status == 0) == success, (scenario, status, text, events)
        marker = root / ("remote/run/" + PREFIX + ".armed")
        if success and scenario != "dry_run":
            assert events.index("arm") < events.index("activate-" + (
                "switch" if scenario == "switch" else "test"))
            assert events.index("fresh-ssh") < events.index("health") < events.index("disarm")
            assert events.index("units-health") < events.index("units-disarm") < events.index("timer-stop")
            assert events.index("timer-stop") < events.index("remove-marker")
            assert not marker.exists() and state["timer"] == "inactive"
            if scenario == "switch":
                assert events.index("arm") < events.index("profile") < events.index("activate-switch")
            else:
                assert "profile" not in events
        elif scenario == "dry_run":
            assert "realise" in events and "diff" in events
            assert "arm" not in events and "profile" not in events
        else:
            assert "remove-marker" not in events, (scenario, text, events)
            if "arm" in events:
                if scenario != "missing_marker":
                    assert marker.exists(), (scenario, text, events)
                assert state["timer"] == "active", (scenario, text, events)
            if scenario in ("fresh_failure", "wrong_closure", "failed_units",
                            "units_failure", "count_failure", "malformed_count",
                            "malformed_units", "activation_failure",
                            "health_empty", "health_malformed", "health_status_failure"):
                assert not final_sent and "disarm" not in events, (scenario, text)
            if scenario in ("service_race", "stop_failure"):
                assert "timer-start" in events, (scenario, text, events)
        if scenario in ("wrong_commit", "wrong_path", "invalid_alias",
                        "invalid_commit", "invalid_path", "missing_option",
                        "status_failure", "dirty", "fetch_failure", "unreviewed",
                        "eval_failure", "cache_failure"):
            assert "ssh" not in events, (scenario, text, events)
        if scenario == "checkout_drift":
            assert "arm" not in events and "Checkout commit drift" in text
        print("PASS deploy " + scenario)
    state_path.write_text(json.dumps({
        "scenario": "noninteractive", "events": [], "alias": True,
    }))
    result = subprocess.run(args, input="", capture_output=True, text=True, env=env)
    events = json.loads(state_path.read_text())["events"]
    assert result.returncode != 0 and "non-interactive activation" in result.stderr
    assert "arm" not in events and "profile" not in events
    print("PASS deploy noninteractive")
    state_path.write_text(json.dumps({
        "scenario": "help", "events": [], "alias": True,
    }))
    result = subprocess.run(["bash", implementation, "--help"],
                            capture_output=True, text=True, env=env)
    assert result.returncode == 0 and "--expected-system-path" in result.stdout
    assert json.loads(state_path.read_text())["events"] == []
    print("PASS deploy help")
    print(f"All {len(scenarios) + 2} isolated deploy regression cases passed.")


if __name__ == "__main__":
    if Path(sys.argv[0]).name == "driver.py":
        main()
    else:
        sys.exit(mock())
PYTHON
chmod +x "$work/driver.py"
TEST_BASH="$(command -v bash)" python3 "$work/driver.py" "$implementation"
