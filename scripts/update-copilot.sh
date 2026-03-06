#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIX_FILE="$SCRIPT_DIR/../packages/github-copilot-cli.nix"

# Fetch latest version from npm
# Prefer stable, but use prerelease if its base version is strictly newer
data=$(curl -s https://registry.npmjs.org/@github/copilot)
stable=$(echo "$data" | jq -r '.["dist-tags"].latest')
prerelease=$(echo "$data" | jq -r '.["dist-tags"].prerelease // empty')
latest="$stable"
if [ -n "$prerelease" ]; then
  pre_base="${prerelease%%-*}"
  if [ "$pre_base" != "$stable" ] && [ "$(printf '%s\n%s' "$stable" "$pre_base" | sort -V | tail -1)" = "$pre_base" ]; then
    latest="$prerelease"
  fi
fi
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
