#!/usr/bin/env bash
set -euo pipefail

# Stage everything
git add -A

# Exit early if nothing to commit
if git diff --cached --quiet; then
  echo "Nothing to commit."
  exit 0
fi

# Generate commit message from the staged diff via Copilot CLI
diff_content="$(git diff --cached)"
msg="$(echo "$diff_content" | copilot -p \
  "Write a concise git commit message (subject line only, no body) for this diff. Output ONLY the message text, nothing else." \
  --no-alt-screen 2>/dev/null | awk 'NF{last=$0} END{print last}')"

if [ -z "$msg" ]; then
  echo "Failed to generate commit message."
  exit 1
fi

git commit -m "$msg"
echo "Committed: $msg"
