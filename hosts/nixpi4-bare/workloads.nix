{ inputs, config, lib, pkgs, ... }:
# Boggle and pogbot are exposed only through the home-initiated edge tunnel.
let
  sopsFileLocation = {
    format = "yaml";
    # nixpi4-bare and nixpi share a device and SSH-derived age identity.
    sopsFile = ../../secrets/nixpi.yaml;
  };

  # Compatibility fixes for pogbot's Python dependencies.
  pythonOverrides = _: pythonPrev:
    {
      inline-snapshot = pythonPrev.inline-snapshot.overridePythonAttrs (
        old:
        lib.optionalAttrs (old.version == "0.34.2") {
          # Upstream's generated-doc snapshots track older Black/Rich output.
          disabledTestPaths = (old.disabledTestPaths or [ ]) ++ [ "tests/test_docs.py" ];
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
  patchedPython312 = pkgs.python312.override { packageOverrides = pythonOverrides; };
  patchedPkgs = pkgs // {
    python312 = patchedPython312;
    python312Packages = patchedPython312.pkgs;
  };
in
{
  imports = [ inputs.pogbot.nixosModules.default ];

  sops.secrets = {
    ASSETS_PATH = sopsFileLocation;
    DISCORD_TOKEN = sopsFileLocation;
    GIPHY_API_KEY = sopsFileLocation;
    OPEN_AI_KEY = sopsFileLocation;
  };

  # Keep service assets independent of the home-manager-managed user home.
  systemd.tmpfiles.rules = [
    "d /srv/pogbot 0750 pogbot pogbot -"
    "d /srv/pogbot/assets 0750 pogbot pogbot -"
  ];

  services.pogbot = {
    enable = true;
    package = pkgs.pogbot.override { pkgs = patchedPkgs; };
    assetsPathFile = config.sops.secrets.ASSETS_PATH.path;
    discordTokenFile = config.sops.secrets.DISCORD_TOKEN.path;
    giphyAPIKeyFile = config.sops.secrets.GIPHY_API_KEY.path;
    openAIAPIKeyFile = config.sops.secrets.OPEN_AI_KEY.path;
    trimmerUrl = "https://mycatsonfire.com/pogbot";
  };

  # Allow workload access only over the overlay, not directly from LAN/internet.
  networking.firewall.interfaces.wg-edge.allowedTCPPorts = [ 8080 8081 ];
}
