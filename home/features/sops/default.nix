{ config, pkgs, ... }:
let
  copilotConfigPath = "${config.home.homeDirectory}/.copilot/config.json";
  sopsFile = ../../../secrets/common.yaml;
  ageKeyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
in
{
  home.activation.ensure-age-key = config.lib.dag.entryBefore [ "inject-copilot-token" ] ''
        if [ ! -f "${ageKeyFile}" ]; then
          echo ""
          echo "=========================================="
          echo "  Age key not found at ${ageKeyFile}"
          echo "=========================================="
          echo ""
          echo "Paste your age key (comments + secret key) and press Enter on an empty line when done:"
          AGE_KEY=""
          while IFS= read -r LINE </dev/tty; do
            [ -z "$LINE" ] && break
            AGE_KEY="$AGE_KEY$LINE
    "
          done
          if echo "$AGE_KEY" | grep -q "^AGE-SECRET-KEY-"; then
            mkdir -p "$(dirname "${ageKeyFile}")"
            echo "$AGE_KEY" > "${ageKeyFile}"
            chmod 600 "${ageKeyFile}"
            echo "Age key saved to ${ageKeyFile}"
          else
            echo "WARNING: Invalid age key format, skipping" >&2
          fi
        fi
  '';

  home.activation.inject-copilot-token = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    copilotConfig="${copilotConfigPath}"
    if [ ! -f "${ageKeyFile}" ]; then
      echo "WARNING: age key not found at ${ageKeyFile}, skipping copilot token injection" >&2
    else
      # Only bootstrap credentials when Copilot has no authenticated user yet.
      # If a working login already exists, leave it completely untouched so a
      # switch never replaces the user you are currently signed in as.
      inject=1
      cleaned=""
      if [ -f "$copilotConfig" ]; then
        # ~/.copilot/config.json is JSONC (leading // comment lines); strip
        # full-line comments so jq can parse it.
        cleaned=$(${pkgs.gnused}/bin/sed '/^[[:space:]]*\/\//d' "$copilotConfig")
        if printf '%s' "$cleaned" | ${pkgs.jq}/bin/jq -e '(.copilotTokens // {}) | length > 0' >/dev/null 2>&1; then
          inject=0
          echo "copilot: existing authenticated user found, leaving credentials untouched"
        elif ! printf '%s' "$cleaned" | ${pkgs.jq}/bin/jq empty >/dev/null 2>&1; then
          inject=0
          echo "WARNING: $copilotConfig is not valid JSON, leaving it untouched" >&2
        fi
      fi

      if [ "$inject" = 1 ]; then
        TOKEN=$(SOPS_AGE_KEY_FILE="${ageKeyFile}" ${pkgs.sops}/bin/sops -d --extract '["copilot-oauth-token"]' ${sopsFile})
        HOST=$(SOPS_AGE_KEY_FILE="${ageKeyFile}" ${pkgs.sops}/bin/sops -d --extract '["copilot-host"]' ${sopsFile})
        LOGIN=$(SOPS_AGE_KEY_FILE="${ageKeyFile}" ${pkgs.sops}/bin/sops -d --extract '["copilot-login"]' ${sopsFile})
        TOKEN_KEY="$HOST:$LOGIN"
        mkdir -p "$(dirname "$copilotConfig")"
        if [ -f "$copilotConfig" ]; then
          printf '%s' "$cleaned" | ${pkgs.jq}/bin/jq \
            --arg token "$TOKEN" --arg key "$TOKEN_KEY" --arg host "$HOST" --arg login "$LOGIN" '
            .copilotTokens[$key] = $token
            | .lastLoggedInUser //= {host: $host, login: $login}
            | .loggedInUsers //= [{host: $host, login: $login}]
          ' > "$copilotConfig.tmp" && mv "$copilotConfig.tmp" "$copilotConfig"
        else
          ${pkgs.jq}/bin/jq -n \
            --arg token "$TOKEN" --arg key "$TOKEN_KEY" --arg host "$HOST" --arg login "$LOGIN" '{
            copilotTokens: {($key): $token},
            lastLoggedInUser: {host: $host, login: $login},
            loggedInUsers: [{host: $host, login: $login}]
          }' > "$copilotConfig"
        fi
        chmod 600 "$copilotConfig"
        echo "copilot: no existing user, bootstrapped credentials for $LOGIN"
      fi
    fi
  '';
}
