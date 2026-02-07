{ config, pkgs, ... }:
let
  copilotConfigPath = "${config.home.homeDirectory}/.copilot/config.json";
  sopsFile = ../../../secrets/common.yaml;
  ageKeyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
in
{
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
