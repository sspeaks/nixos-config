#!/bin/bash
# ralph-prd - Generate prd.json interactively using Copilot CLI
# Usage: ralph-prd "your feature description"

set -e

SKILLS_DIR="${HOME}/.copilot/skills"
SKILLS_REPO_BASE="https://raw.githubusercontent.com/snarktank/ralph/main/skills"

if [ -z "$1" ]; then
  echo "Usage: ralph-prd \"your feature description\""
  echo ""
  echo "Opens an interactive Copilot CLI session to:"
  echo "  1. Generate a PRD with clarifying questions"
  echo "  2. Convert the PRD to prd.json for use with ralph"
  exit 1
fi

if ! command -v copilot &>/dev/null; then
  echo "Error: copilot CLI not found. Install with: npm install -g @github/copilot"
  exit 1
fi

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

FEATURE_DESC="$*"

PROMPT="I need you to help me create a prd.json file for the following feature:

${FEATURE_DESC}

Please follow this process:
1. First, use the prd skill to generate a PRD. Ask me clarifying questions with lettered options so I can respond quickly (e.g. \"1A, 2C, 3B\"). Save the PRD to tasks/ directory.
2. After I've answered your questions and you've generated the PRD, use the ralph skill to convert it to prd.json in the current working directory.

Start by asking me the clarifying questions."

echo "Starting interactive Copilot session for PRD generation..."
echo "Feature: ${FEATURE_DESC}"
echo ""

copilot -i "$PROMPT"
