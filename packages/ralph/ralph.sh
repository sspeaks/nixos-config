#!/bin/bash
# Ralph - Autonomous AI agent loop using GitHub Copilot CLI
# Usage: ralph [max_iterations]
# Run from a directory containing prd.json

set -e

MAX_ITERATIONS=10
SKILLS_DIR="${HOME}/.copilot/skills"
PROMPT_FILE="${HOME}/.copilot/ralph-prompt.md"
SKILLS_REPO_BASE="https://raw.githubusercontent.com/snarktank/ralph/main/skills"

# Parse arguments
while [[ $# -gt 0 ]]; do
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    MAX_ITERATIONS="$1"
  fi
  shift
done

# Bootstrap skills if missing
bootstrap_skills() {
  local changed=0
  if [ ! -f "${SKILLS_DIR}/prd/SKILL.md" ]; then
    echo "Bootstrapping prd skill..."
    mkdir -p "${SKILLS_DIR}/prd"
    curl -fsSL "${SKILLS_REPO_BASE}/prd/SKILL.md" -o "${SKILLS_DIR}/prd/SKILL.md"
    changed=1
  fi
  if [ ! -f "${SKILLS_DIR}/ralph/SKILL.md" ]; then
    echo "Bootstrapping ralph skill..."
    mkdir -p "${SKILLS_DIR}/ralph"
    curl -fsSL "${SKILLS_REPO_BASE}/ralph/SKILL.md" -o "${SKILLS_DIR}/ralph/SKILL.md"
    changed=1
  fi
  if [ "$changed" -eq 1 ]; then
    echo "Skills installed to ${SKILLS_DIR}"
  fi
}

bootstrap_skills

# Validate environment
PRD_FILE="./prd.json"
PROGRESS_FILE="./progress.txt"
ARCHIVE_DIR="./archive"
LAST_BRANCH_FILE="./.ralph-last-branch"

if [ ! -f "$PRD_FILE" ]; then
  echo "Error: No prd.json found in current directory."
  echo "Create one with: ralph-prd \"your feature description\""
  exit 1
fi

if ! command -v copilot &>/dev/null; then
  echo "Error: copilot CLI not found. Install with: npm install -g @github/copilot"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq not found. Install it for your platform."
  exit 1
fi

if [ ! -f "$PROMPT_FILE" ]; then
  echo "Error: Ralph prompt template not found at ${PROMPT_FILE}"
  exit 1
fi

# Archive previous run if branch changed
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")

  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    DATE=$(date +%Y-%m-%d)
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"

    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "   Archived to: $ARCHIVE_FOLDER"

    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

# Track current branch
CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
if [ -n "$CURRENT_BRANCH" ]; then
  echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
fi

# Initialize progress file if needed
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

PROMPT=$(cat "$PROMPT_FILE")

echo "Starting Ralph - Max iterations: $MAX_ITERATIONS"

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo "==============================================================="
  echo "  Ralph Iteration $i of $MAX_ITERATIONS (Copilot CLI)"
  echo "==============================================================="

  OUTPUT=$(copilot -p "$PROMPT" --yolo 2>&1 | tee /dev/stderr) || true

  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Ralph completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    exit 0
  fi

  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
