{ pkgs, config, lib, ... }:
let
  copilotConfigPath = "/home/sspeaks/.copilot/config.json";
  hasMyCopilot =
    lib.elem pkgs.myCopilot
      (lib.attrByPath [ "home-manager" "users" "sspeaks" "home" "packages" ] [ ] config);
  copilotActivationScript = pkgs.writeShellScript "inject-copilot-token" ''
    copilotConfig="${copilotConfigPath}"
    # Only bootstrap credentials when Copilot has no authenticated user yet.
    # If a working login already exists, leave it completely untouched so a
    # rebuild never replaces the user you are currently signed in as.
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
      TOKEN=$(cat ${config.sops.secrets.copilot-oauth-token.path})
      HOST=$(cat ${config.sops.secrets.copilot-host.path})
      LOGIN=$(cat ${config.sops.secrets.copilot-login.path})
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
      chown sspeaks:users "$copilotConfig"
      chmod 600 "$copilotConfig"
      echo "copilot: no existing user, bootstrapped credentials for $LOGIN"
    fi
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

  system.activationScripts.inject-copilot-token = lib.mkIf hasMyCopilot (lib.stringAfter [ "setupSecrets" ] ''
    ${copilotActivationScript}
  '');

  sops.secrets.open-ai-api-key = {
    mode = "400";
    owner = "sspeaks";
    group = "users";
  };
  environment.systemPackages = [
    pkgs.net-tools
  ];

  programs.zsh.enable = true;
  users.mutableUsers = false;
  users.users.sspeaks = {
    shell = pkgs.zsh;
    isNormalUser = true;
    extraGroups = [ "wheel" "input" ];
    hashedPasswordFile = config.sops.secrets.sspeaks-password.path;
  };
}
