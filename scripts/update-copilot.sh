#!/usr/bin/env bash
set -euo pipefail

# Re-exec inside a nix shell with required tools when not already wrapped.
# Uses the flake registry instead of <nixpkgs>, which is unset on flake-only setups.
if [ -z "${_UPDATE_COPILOT_WRAPPED:-}" ]; then
  export _UPDATE_COPILOT_WRAPPED=1
  exec nix shell nixpkgs#curl nixpkgs#jq nixpkgs#nix --command bash "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIX_FILE="$SCRIPT_DIR/../packages/github-copilot-cli.nix"

release_json=$(mktemp)
trap 'rm -f "$release_json"' EXIT

# Fetch latest release metadata from GitHub.
curl -fsSL https://api.github.com/repos/github/copilot-cli/releases/latest -o "$release_json"
latest=$(jq -r '.tag_name | sub("^v"; "")' "$release_json")
current=$(grep 'version = ' "$NIX_FILE" | head -1 | sed 's/.*"\(.*\)".*/\1/')

if [ -z "$latest" ] || [ "$latest" = "null" ]; then
  echo "ERROR: could not read latest Copilot CLI release version" >&2
  exit 1
fi

echo "Current: $current"
echo "Latest:  $latest"

if [ "$current" = "$latest" ]; then
  echo "Already up to date."
  exit 0
fi

echo "Updating $current → $latest"

# Platform mapping: nix system -> tarball name
declare -A platforms=(
  ["x86_64-linux"]="copilot-linux-x64"
  ["aarch64-linux"]="copilot-linux-arm64"
  ["x86_64-darwin"]="copilot-darwin-x64"
  ["aarch64-darwin"]="copilot-darwin-arm64"
)

# Read published GitHub asset digests for all platforms.
declare -A hashes
for system in "${!platforms[@]}"; do
  name="${platforms[$system]}"
  asset="${name}.tar.gz"
  digest=$(jq -r --arg name "$asset" '
    .assets[]
    | select(.name == $name)
    | .digest // empty
  ' "$release_json")

  if [[ ! "$digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
    echo "ERROR: missing sha256 digest for $asset in GitHub release v$latest" >&2
    exit 1
  fi

  hash=$(nix hash convert --hash-algo sha256 --from base16 --to sri "${digest#sha256:}")
  hashes[$system]="$hash"
  echo "  $system: $hash"
done

# Update the version
sed -i "s/version = \"$current\"/version = \"$latest\"/" "$NIX_FILE"

# Update each platform hash
for system in "${!platforms[@]}"; do
  name="${platforms[$system]}"
  new_hash="${hashes[$system]}"
  # Match the hash line that follows the platform's name line
  sed -i "/$name/{n;s|hash = \".*\"|hash = \"$new_hash\"|}" "$NIX_FILE"
done

echo "Updated $NIX_FILE to v$latest — rebuild and commit when ready."
