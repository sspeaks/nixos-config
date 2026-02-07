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
    if [ -f "${ageKeyFile}" ]; then
      TOKEN=$(SOPS_AGE_KEY_FILE="${ageKeyFile}" ${pkgs.sops}/bin/sops -d --extract '["copilot-oauth-token"]' ${sopsFile})
      HOST=$(SOPS_AGE_KEY_FILE="${ageKeyFile}" ${pkgs.sops}/bin/sops -d --extract '["copilot-host"]' ${sopsFile})
      LOGIN=$(SOPS_AGE_KEY_FILE="${ageKeyFile}" ${pkgs.sops}/bin/sops -d --extract '["copilot-login"]' ${sopsFile})
      TOKEN_KEY="$HOST:$LOGIN"
      mkdir -p "$(dirname "${copilotConfigPath}")"
      if [ -f "${copilotConfigPath}" ]; then
        EXISTING_KEY=$(${pkgs.jq}/bin/jq -r '.copilot_tokens // {} | keys[0] // empty' "${copilotConfigPath}")
        KEY="''${EXISTING_KEY:-$TOKEN_KEY}"
        ${pkgs.jq}/bin/jq --arg token "$TOKEN" --arg key "$KEY" \
          --arg host "$HOST" --arg login "$LOGIN" '
          .copilot_tokens[$key] = $token |
          .last_logged_in_user //= {"host": $host, "login": $login} |
          .logged_in_users //= [{"host": $host, "login": $login}]
        ' "${copilotConfigPath}" > "${copilotConfigPath}.tmp" \
          && mv "${copilotConfigPath}.tmp" "${copilotConfigPath}"
      else
        ${pkgs.jq}/bin/jq -n --arg token "$TOKEN" --arg key "$TOKEN_KEY" \
          --arg host "$HOST" --arg login "$LOGIN" '{
          copilot_tokens: {($key): $token},
          last_logged_in_user: {"host": $host, "login": $login},
          logged_in_users: [{"host": $host, "login": $login}]
        }' > "${copilotConfigPath}"
      fi
      chmod 600 "${copilotConfigPath}"
    else
      echo "WARNING: age key not found at ${ageKeyFile}, skipping copilot token injection" >&2
    fi
  '';
}
