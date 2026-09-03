{ inputs, config, lib, pkgs, ... }:
# P3.1 — Boggle and pogbot, migrated off the Azure `nixos` VM.
#
# Both were previously reached by Caddy at the VM's public hostname. They are
# now behind the home-initiated tunnel, so the edge reaches them at
# 10.10.0.3 and nothing on the home network accepts an inbound connection.
let
  sopsFileLocation = {
    format = "yaml";
    # nixpi4-bare shares the nixpi age identity: same Pi, same SD card,
    # therefore the same SSH host key.
    sopsFile = ../../secrets/nixpi.yaml;
  };

  # Carried over verbatim from hosts/pogbot/pogbot.nix. These overrides are not
  # optional decoration: without them pogbot's Python closure fails to build.
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

  # Clip assets live outside the user's home so the service does not depend on
  # a home directory that home-manager rewrites.
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

  # Only the overlay needs to reach these; they are never LAN- or
  # internet-exposed directly.
  networking.firewall.interfaces.wg-edge.allowedTCPPorts = [ 8080 8081 ];
}
