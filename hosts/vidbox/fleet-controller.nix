{ config, lib, pkgs, outputs, ... }:
# vidbox is the fleet controller: `update-fleet` runs here as sspeaks.
#
# - SSH: ~/.ssh/id_fleet (generated on this host, its public key is in
#   hosts/common/users/sspeaks/authorized-keys.nix) and host keys pinned below,
#   so update-fleet's StrictHostKeyChecking=yes never needs a prompt.
# - GitHub: a fine-grained token (Actions: read, Contents: read on
#   sspeaks/nixos-config) from sops, exported as GH_TOKEN.
# - Checkout: update-fleet requires one; clone it once to ~/nixos-config.
let
  fleetHosts = {
    raspberrytimemachine = {
      hostNames = [ "192.168.5.106" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE7M3FY2nhYbVTVYeZltA2/VRF/jN1QHpFdwogfQwxd8";
    };
    # update-fleet connects with HostKeyAlias=nixpi4-bare for this host.
    nixpi4-bare = {
      hostNames = [ "nixpi4-bare" "192.168.5.16" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO64hfD5gr0lc1vnbxw+PQ50IZ2UcXKQCXNfNH2STZwQ";
    };
    nixpi5 = {
      hostNames = [ "192.168.5.238" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKznWaEIrs/C24Dux9HUOfPOFOnHR3pMeapI0PRfPNAe";
    };
    proxy = {
      hostNames = [ "20.83.103.87" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFlZaluTlCUJ7VLHcMyFO+s3EqeAd63oQK0DsWFZ0Zo4";
    };
    vidbox = {
      hostNames = [ "vidbox" "192.168.5.178" "localhost" "127.0.0.1" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAF9lP/zaNC0Re1TUiAVmJ2CsMvXsOOEsZSfNP9oPsG+";
    };
  };
  identityHosts = lib.concatStringsSep " "
    (lib.unique (lib.concatMap (h: h.hostNames) (lib.attrValues fleetHosts)));

  update-fleet = pkgs.writeShellScriptBin "update-fleet" ''
    set -eu
    token_file=${lib.escapeShellArg config.sops.secrets.github-fleet-token.path}
    if [ -z "''${GH_TOKEN:-}" ]; then
      GH_TOKEN="$(cat "$token_file")" || {
        echo "update-fleet: cannot read $token_file (run as sspeaks)" >&2
        exit 1
      }
      export GH_TOKEN
    fi
    export FLEET_DEFAULT_REPO="''${FLEET_DEFAULT_REPO:-$HOME/nixos-config}"
    [ -d "$FLEET_DEFAULT_REPO/.git" ] || {
      echo "update-fleet: no checkout at $FLEET_DEFAULT_REPO; run: gh repo clone sspeaks/nixos-config $FLEET_DEFAULT_REPO" >&2
      exit 1
    }
    exec ${lib.getExe outputs.packages.${pkgs.stdenv.hostPlatform.system}.update-fleet} "$@"
  '';
in
{
  sops.secrets.github-fleet-token = {
    format = "yaml";
    sopsFile = ../../secrets/vidbox.yaml;
    owner = "sspeaks";
    mode = "0400";
  };

  programs.ssh.knownHosts = fleetHosts;
  programs.ssh.extraConfig = ''
    Host ${identityHosts}
      IdentityFile ~/.ssh/id_fleet
  '';

  environment.systemPackages = [ update-fleet pkgs.gh pkgs.git ];
}
