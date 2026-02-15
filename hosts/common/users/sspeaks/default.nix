{ pkgs, config, lib, ... }:
let
  copilotConfigPath = "/home/sspeaks/.copilot/config.json";
  copilotActivationScript = pkgs.writeShellScript "inject-copilot-token" ''
    TOKEN=$(cat ${config.sops.secrets.copilot-oauth-token.path})
    HOST=$(cat ${config.sops.secrets.copilot-host.path})
    LOGIN=$(cat ${config.sops.secrets.copilot-login.path})
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
    chown sspeaks:users "${copilotConfigPath}"
    chmod 600 "${copilotConfigPath}"
  '';
in
{
  sops.secrets.sspeaks-password.neededForUsers = true;

  sops.secrets.github-ssh-private = {
    path = "/home/sspeaks/.ssh/github";
    owner = "sspeaks";
    group = "users";
    mode = "0600";
  };
  sops.secrets.copilot-oauth-token = {
    owner = "sspeaks";
    group = "users";
    mode = "0600";
  };
  sops.secrets.copilot-host = {
    owner = "sspeaks";
    group = "users";
    mode = "0600";
  };
  sops.secrets.copilot-login = {
    owner = "sspeaks";
    group = "users";
    mode = "0600";
  };

  system.activationScripts.inject-copilot-token = lib.stringAfter [ "setupSecrets" ] ''
    ${copilotActivationScript}
  '';

  sops.secrets.open-ai-api-key = {
    mode = "444";
    owner = "sspeaks";
    group = "users";
  };
  environment.systemPackages = [
    (pkgs.askGPT4.override {
      openaikey = config.sops.secrets.open-ai-api-key.path;
    })
    pkgs.net-tools
  ];

  programs.zsh.enable = true;
  users.mutableUsers = false;
  users.users.sspeaks = {
    shell = pkgs.zsh;
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" "input" ];
    hashedPasswordFile = config.sops.secrets.sspeaks-password.path;
  };
}
