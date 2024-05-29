{ pkgs, config, lib, ... }:
{
  sops.secrets.sspeaks-password.neededForUsers = true;

  sops.secrets.github-ssh-private = {
    path = "/home/sspeaks/.ssh/github";
    owner = "sspeaks";
    group = "users";
    mode = "0600";
  };

  programs.zsh.enable = true;
  users.mutableUsers = false;
  users.users.sspeaks = {
    shell = pkgs.zsh;
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    hashedPasswordFile = config.sops.secrets.sspeaks-password.path;
  };
}
