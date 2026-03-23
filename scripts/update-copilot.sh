#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq nix
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIX_FILE="$SCRIPT_DIR/../packages/github-copilot-cli.nix"

# Fetch latest release version from GitHub
latest=$(curl -s https://api.github.com/repos/github/copilot-cli/releases/latest | jq -r '.tag_name' | sed 's/^v//')
current=$(grep 'version = ' "$NIX_FILE" | head -1 | sed 's/.*"\(.*\)".*/\1/')

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

# Prefetch hashes for all platforms
declare -A hashes
for system in "${!platforms[@]}"; do
  name="${platforms[$system]}"
  url="https://github.com/github/copilot-cli/releases/download/v${latest}/${name}.tar.gz"
  echo "Prefetching $name..."
  hash=$(nix store prefetch-file --json "$url" | jq -r '.hash')
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
