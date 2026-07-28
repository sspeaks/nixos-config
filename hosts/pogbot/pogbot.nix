{ inputs, config, lib, pkgs, ... }:
let
  sopsFileLocation = {
    format = "yaml";
    sopsFile = ../../secrets/nixos-azure.yaml;
  };
  python312Packages = pkgs.python312Packages // {
    buildPythonPackage = args:
      pkgs.python312Packages.buildPythonPackage (args // lib.optionalAttrs (
        (args.pname or null) == "discord_ext_voice_recv"
        && (args.version or null) == "0.5.2a179"
      ) {
        version = "0.5.2a0";
      });
  };
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
    package = pkgs.pogbot.override { pkgs = pkgs // { inherit python312Packages; }; };
    assetsPathFile = config.sops.secrets.ASSETS_PATH.path;
    discordTokenFile = config.sops.secrets.DISCORD_TOKEN.path;
    giphyAPIKeyFile = config.sops.secrets.GIPHY_API_KEY.path;
    openAIAPIKeyFile = config.sops.secrets.OPEN_AI_KEY.path;
    trimmerUrl = "https://mycatsonfire.com/pogbot";
  };
}
