#!/usr/bin/env bash
set -euo pipefail

# Re-exec inside a nix shell with required tools when not already wrapped.
# Uses the flake registry instead of <nixpkgs>, which is unset on flake-only setups.
if [ -z "${_UPDATE_SQUAD_CLI_WRAPPED:-}" ]; then
  export _UPDATE_SQUAD_CLI_WRAPPED=1
  exec nix shell nixpkgs#bash nixpkgs#curl nixpkgs#gnutar nixpkgs#jq nixpkgs#nix nixpkgs#nodejs nixpkgs#perl nixpkgs#prefetch-npm-deps --command bash "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR/../packages/squad-cli"
NIX_FILE="$PACKAGE_DIR/default.nix"
LOCK_FILE="$PACKAGE_DIR/package-lock.json"

metadata_json=$(mktemp)
work_dir=$(mktemp -d)
trap 'rm -f "$metadata_json"; rm -rf "$work_dir"' EXIT

curl -fsSL https://registry.npmjs.org/@bradygaster%2fsquad-cli/latest -o "$metadata_json"

latest=$(jq -r '.version // empty' "$metadata_json")
tarball=$(jq -r '.dist.tarball // empty' "$metadata_json")
source_hash=$(jq -r '.dist.integrity // empty' "$metadata_json")
current=$(grep 'version = ' "$NIX_FILE" | head -1 | sed 's/.*"\(.*\)".*/\1/')

if [ -z "$latest" ]; then
  echo "ERROR: could not read latest squad-cli version" >&2
  exit 1
fi

if [ -z "$tarball" ]; then
  echo "ERROR: could not read squad-cli tarball URL for v$latest" >&2
  exit 1
fi

if [[ ! "$source_hash" =~ ^sha(256|384|512)-[A-Za-z0-9+/=]+$ ]]; then
  echo "ERROR: invalid or missing source integrity for squad-cli v$latest" >&2
  exit 1
fi

echo "Current: $current"
echo "Latest:  $latest"

if [ "$current" = "$latest" ]; then
  echo "Version is up to date; refreshing source and dependency hashes."
else
  echo "Updating $current -> $latest"
fi

curl -fsSL "$tarball" -o "$work_dir/squad-cli.tgz"
tar -xzf "$work_dir/squad-cli.tgz" -C "$work_dir"

(
  cd "$work_dir/package"
  npm install --package-lock-only --ignore-scripts --omit=dev --loglevel=error
)

npm_deps_hash=$(prefetch-npm-deps "$work_dir/package/package-lock.json" | tail -1)
if [[ ! "$npm_deps_hash" =~ ^sha256-[A-Za-z0-9+/=]+$ ]]; then
  echo "ERROR: invalid npmDepsHash from prefetch-npm-deps: $npm_deps_hash" >&2
  exit 1
fi

replace_file() {
  local file=$1
  shift

  local tmp
  tmp=$(mktemp)
  if "$@" "$file" >"$tmp"; then
    mv "$tmp" "$file"
  else
    rm -f "$tmp"
    return 1
  fi
}

if [ "$current" != "$latest" ]; then
  if ! CURRENT="$current" LATEST="$latest" replace_file "$NIX_FILE" perl -0pe '
    BEGIN { $updated = 0 }
    my $current = quotemeta $ENV{CURRENT};
    $updated += s/version = "$current"/version = "$ENV{LATEST}"/;
    END { exit($updated ? 0 : 1) }
  '; then
    echo "ERROR: failed to update version in $NIX_FILE" >&2
    exit 1
  fi
fi

if ! SOURCE_HASH="$source_hash" replace_file "$NIX_FILE" perl -0pe '
  BEGIN { $updated = 0 }
  $updated += s/(src = fetchurl \{\n\s*url = "https:\/\/registry\.npmjs\.org\/\@bradygaster\/squad-cli\/-\/squad-cli-\$\{version\}\.tgz";\n\s*hash = ")[^"]+(";\n\s*\};)/$1$ENV{SOURCE_HASH}$2/s;
  END { exit($updated ? 0 : 1) }
'; then
  echo "ERROR: failed to update source hash in $NIX_FILE" >&2
  exit 1
fi

if ! NPM_DEPS_HASH="$npm_deps_hash" replace_file "$NIX_FILE" perl -0pe '
  BEGIN { $updated = 0 }
  $updated += s/(npmDepsHash = ")[^"]+(")/$1$ENV{NPM_DEPS_HASH}$2/;
  END { exit($updated ? 0 : 1) }
'; then
  echo "ERROR: failed to update npmDepsHash in $NIX_FILE" >&2
  exit 1
fi

cp "$work_dir/package/package-lock.json" "$LOCK_FILE"

echo "Updated $NIX_FILE and $LOCK_FILE to v$latest — rebuild and commit when ready."
