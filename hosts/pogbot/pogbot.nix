{ inputs, config, lib, pkgs, ... }:
let
  sopsFileLocation = {
    format = "yaml";
    sopsFile = ../../secrets/nixos-azure.yaml;
  };
  pythonOverrides = _: pythonPrev:
    {
      inline-snapshot = pythonPrev.inline-snapshot.overridePythonAttrs (
        old:
        lib.optionalAttrs (old.version == "0.34.2") {
          # Upstream's generated-doc snapshots track older Black/Rich output.
          # Keep the functional test suite enabled while excluding those docs.
          disabledTestPaths = (old.disabledTestPaths or [ ]) ++ [
            "tests/test_docs.py"
          ];
        }
      );
    }
    // {
      buildPythonPackage = args:
        pythonPrev.buildPythonPackage (
          if lib.isAttrs args && (args.pname or null) == "discord_ext_voice_recv" then
            args // {
              postPatch = (args.postPatch or "") + ''
                substituteInPlace discord/ext/voice_recv/__init__.py \
                  --replace-fail "__version__ = '0.5.2a'" "__version__ = '${args.version}'"
              '';
            }
          else
            args
        );
    };
  patchedPython312 = pkgs.python312.override {
    packageOverrides = pythonOverrides;
  };
  patchedPython312Packages = patchedPython312.pkgs;
  patchedPkgs = pkgs // {
    python312 = patchedPython312;
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
