#!/usr/bin/env bash
set -euo pipefail

timeout_duration="${GAC_COPILOT_TIMEOUT:-15s}"

last_non_empty_line() {
  awk 'NF { line = $0 } END { gsub(/^[[:space:]]+|[[:space:]]+$/, "", line); print line }'
}

fallback_commit_message() {
  local count first_file verb
  count=$(git diff --cached --name-only | awk 'END { print NR }')
  first_file=$(git diff --cached --name-only | awk 'NR == 1 { print; exit }')
  verb=$(git diff --cached --name-status | awk 'NR == 1 {
    if ($1 == "A") print "Add";
    else if ($1 == "D") print "Remove";
    else if ($1 == "R") print "Rename";
    else print "Update";
    exit
  }')

  if [ "$count" -eq 1 ]; then
    printf '%s %s\n' "$verb" "$first_file"
  else
    printf 'Update %s files\n' "$count"
  fi
}

# Stage everything
git add -A

# Exit early if nothing to commit
if git diff --cached --quiet; then
  echo "Nothing to commit."
  exit 0
fi

# Generate a commit message from a bounded staged summary via Copilot CLI.
diff_summary=$(
  {
    echo "Changed files:"
    git diff --cached --name-status
    echo
    echo "Diff stats:"
    git diff --cached --stat --compact-summary
  }
)

prompt=$(cat <<EOF
Write a concise git commit subject line for these staged changes.
Use imperative mood, keep it under 72 characters, and output only the subject line.

$diff_summary
EOF
)

echo "Generating commit message with Copilot..."
copilot_error=$(mktemp)
if command -v timeout >/dev/null 2>&1; then
  if copilot_output=$(timeout "$timeout_duration" copilot -p "$prompt" 2>"$copilot_error"); then
    msg=$(printf '%s\n' "$copilot_output" | last_non_empty_line)
  else
    status=$?
    if [ "$status" -eq 124 ]; then
      echo "Copilot timed out after $timeout_duration; using fallback commit message." >&2
      msg=$(fallback_commit_message)
    else
      cat "$copilot_error" >&2
      rm -f "$copilot_error"
      exit "$status"
    fi
  fi
else
  if copilot_output=$(copilot -p "$prompt" 2>"$copilot_error"); then
    msg=$(printf '%s\n' "$copilot_output" | last_non_empty_line)
  else
    status=$?
    cat "$copilot_error" >&2
    rm -f "$copilot_error"
    exit "$status"
  fi
fi
rm -f "$copilot_error"

if [ -z "$msg" ]; then
  echo "Copilot returned an empty commit message; using fallback commit message." >&2
  msg=$(fallback_commit_message)
fi

git commit -m "$msg"
echo "Committed: $msg"
