{ pkgs, lib, inputs, ... }:
# `vidbox` -- the home Hyper-V VM that takes over vid-stream's workload from
# Azure, retiring the last expensive VM in the estate.
#
# ---------------------------------------------------------------------------
# PASS TWO IS NOW ACTIVE. The history matters, so it is recorded here.
#
# A freshly installed host has no sops identity. sops-nix derives its age key
# from /etc/ssh/ssh_host_ed25519_key, which does not exist until the installer
# has run, so its public half cannot be in .sops.yaml beforehand and the host
# cannot decrypt secrets/common.yaml on first boot. The proxy hit exactly this
# in P4.1 and shipped with its rescue account locked for the same reason.
#
# Pass one therefore ran WITHOUT ../common/users/sspeaks -- that module declares
# sops secrets (sspeaks-password with neededForUsers, the github ssh key, three
# copilot secrets, the OpenAI key) and every one would have failed to decrypt,
# taking user creation down with it and leaving an unloginable machine. The user
# was defined inline instead, key-only with a locked password.
#
# Pass two, done: the host key was scanned, converted with ssh-to-age to
# age16mhhzl87..., added to .sops.yaml under hosts and to the common.yaml rule,
# and common.yaml was re-encrypted (10 recipients -> 11). The inline user has
# been replaced by the shared module below.
#
# `determinate` is back too. It follows this flake's nixpkgs, so it is NOT in
# Determinate's own cache -- but hosts/vid-stream already imports it, so CI has
# been publishing that exact x86_64 derivation to sspeaks-nix all along. The
# installer only ever rebuilt it (wasmtime, via rustc) because the live ISO had
# no access to that cache. The installed system does.
# ---------------------------------------------------------------------------
{
  imports = [
    ../common/global
    ../common/users/sspeaks
    ../common/users/sspeaks/authorized-keys.nix
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.home-manager
    inputs.determinate.nixosModules.default
  ];

  home-manager.useUserPackages = true;
  home-manager.users.sspeaks = { ... }: {
    imports = [ ../../home/sspeaks-bare.nix ];
  };

  # Matches the other servers. wheelNeedsPassword = false is what makes
  # nixos-anywhere and ./deploy able to activate without an interactive prompt.
  security.sudo.wheelNeedsPassword = false;
  programs.nix-ld.enable = true;

  time.timeZone = "America/Los_Angeles";
}
