{ pkgs, config, lib, ... }:
{
  sops.secrets.sspeaks-password.neededForUsers = true;

  programs.zsh.enable = true;
  users.mutableUsers = false;
  users.users.sspeaks = {
    shell = pkgs.zsh;
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    hashedPasswordFile = config.sops.secrets.sspeaks-password.path;
  };
}
