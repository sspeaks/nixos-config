{ inputs, config, ... }:
let
  sopsFileLocation = {
    format = "yaml";
    sopsFile = ../../secrets/nixos-azure.yaml;
  };
  rf = filePath: builtins.readFile filePath;
in
{
  imports = [
    inputs.pogbot.nixosModules.default
  ];

  sops.secrets = {
    ASSETS_PATH = sopsFileLocation;
    DISCORD_TOKEN = sopsFileLocation;
    GIPHY_API_KEY = sopsFileLocation;
    OPEN_AI_KEY = sopsFileLocation;
  };

  services.pogbot = {
    enable = true;
    assetsPathFile = config.sops.secrets.ASSETS_PATH.path;
    discordTokenFile = config.sops.secrets.DISCORD_TOKEN.path;
    giphyAPIKeyFile = config.sops.secrets.GIPHY_API_KEY.path;
    openAIAPIKeyFile = config.sops.secrets.OPEN_AI_KEY.path;
  };
}
