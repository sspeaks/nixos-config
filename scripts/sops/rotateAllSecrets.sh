#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

find "$REPO_ROOT/secrets" -type f -name "*.yaml" -exec "$SCRIPT_DIR/rotateSecrets.sh" {} \;
