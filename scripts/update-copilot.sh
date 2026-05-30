#!/usr/bin/env bash
set -euo pipefail

# Re-exec inside a nix shell with required tools when not already wrapped.
# Uses the flake registry instead of <nixpkgs>, which is unset on flake-only setups.
if [ -z "${_UPDATE_COPILOT_WRAPPED:-}" ]; then
  export _UPDATE_COPILOT_WRAPPED=1
  exec nix shell nixpkgs#bash nixpkgs#curl nixpkgs#jq nixpkgs#nix nixpkgs#perl --command bash "$0" "$@"
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

# Platform mapping: "<nix system> <tarball name>"
platforms=(
  "x86_64-linux copilot-linux-x64"
  "aarch64-linux copilot-linux-arm64"
  "x86_64-darwin copilot-darwin-x64"
  "aarch64-darwin copilot-darwin-arm64"
)

replace_file() {
  local tmp
  tmp=$(mktemp)
  if "$@" >"$tmp"; then
    mv "$tmp" "$NIX_FILE"
  else
    rm -f "$tmp"
    return 1
  fi
}

hashes_file=$(mktemp)
trap 'rm -f "$release_json" "$hashes_file"' EXIT

# Read published GitHub asset digests for all platforms.
for platform in "${platforms[@]}"; do
  system="${platform%% *}"
  name="${platform#* }"
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
  printf '%s %s %s\n' "$system" "$name" "$hash" >>"$hashes_file"
  echo "  $system: $hash"
done

# Update the version
if ! CURRENT="$current" LATEST="$latest" replace_file perl -0pe '
  BEGIN { $updated = 0 }
  my $current = quotemeta $ENV{CURRENT};
  $updated += s/version = "$current"/version = "$ENV{LATEST}"/;
  END { exit($updated ? 0 : 1) }
' "$NIX_FILE"; then
  echo "ERROR: failed to update version in $NIX_FILE" >&2
  exit 1
fi

# Update each platform hash
while IFS=' ' read -r system name new_hash; do
  if ! ASSET_NAME="$name" NEW_HASH="$new_hash" replace_file perl -0pe '
    BEGIN { $updated = 0 }
    my $name = quotemeta $ENV{ASSET_NAME};
    my $hash = $ENV{NEW_HASH};
    $updated += s/(name = "$name";\n\s*hash = ")[^"]+(")/$1$hash$2/;
    END { exit($updated ? 0 : 1) }
  ' "$NIX_FILE"; then
    echo "ERROR: failed to update hash for $system ($name) in $NIX_FILE" >&2
    exit 1
  fi
done <"$hashes_file"

echo "Updated $NIX_FILE to v$latest — rebuild and commit when ready."
