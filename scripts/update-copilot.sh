#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIX_FILE="$SCRIPT_DIR/../packages/github-copilot-cli.nix"

# Fetch latest version from npm
latest=$(curl -s https://registry.npmjs.org/@github/copilot | jq -r '.["dist-tags"].prerelease // .["dist-tags"].latest')
current=$(grep 'version = ' "$NIX_FILE" | sed 's/.*"\(.*\)".*/\1/')

echo "Current: $current"
echo "Latest:  $latest"

if [ "$current" = "$latest" ]; then
  echo "Already up to date."
  exit 0
fi

echo "Updating $current → $latest"

# Prefetch the new tarball and get SRI hash
url="https://registry.npmjs.org/@github/copilot/-/copilot-${latest}.tgz"
hash=$(nix store prefetch-file --unpack --json "$url" | jq -r '.hash')

echo "New hash: $hash"

# Update version and hash in the nix file
sed -i "s|version = \"$current\"|version = \"$latest\"|" "$NIX_FILE"
sed -i "s|hash = \".*\"|hash = \"$hash\"|" "$NIX_FILE"

echo "Updated $NIX_FILE — rebuild and commit when ready."
