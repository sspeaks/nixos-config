{ inputs, config, lib, pkgs, ... }:
let
  sopsFileLocation = {
    format = "yaml";
    sopsFile = ../../secrets/nixos-azure.yaml;
  };
  patchedPython312Packages = pkgs.python312Packages.overrideScope
    (_: pythonPrev: {
      buildPythonPackage = args:
        pythonPrev.buildPythonPackage (args // lib.optionalAttrs
          ((args.pname or null) == "discord_ext_voice_recv")
          {
            postPatch = (args.postPatch or "") + ''
              substituteInPlace discord/ext/voice_recv/__init__.py \
                --replace-fail "__version__ = '0.5.2a'" "__version__ = '${args.version}'"
            '';
          });
    });
  patchedPkgs = pkgs // {
    python312Packages = patchedPython312Packages;
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
    package = pkgs.pogbot.override { pkgs = patchedPkgs; };
    assetsPathFile = config.sops.secrets.ASSETS_PATH.path;
    discordTokenFile = config.sops.secrets.DISCORD_TOKEN.path;
    giphyAPIKeyFile = config.sops.secrets.GIPHY_API_KEY.path;
    openAIAPIKeyFile = config.sops.secrets.OPEN_AI_KEY.path;
    trimmerUrl = "https://mycatsonfire.com/pogbot";
  };
}
