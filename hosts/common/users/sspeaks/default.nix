{ pkgs, config, lib, ... }:
{
  sops.secrets.sspeaks-password.neededForUsers = true;

  sops.secrets.github-ssh-private = {
    path = "/home/sspeaks/.ssh/github";
    owner = "sspeaks";
    group = "users";
    mode = "0600";
  };
  sops.secrets.open-ai-api-key = {
    mode = "444";
    owner = "sspeaks";
    group = "users";
  };
  environment.systemPackages = [
    (pkgs.askGPT4.override {
      openaikey = config.sops.secrets.open-ai-api-key.path;
    })
  ];

  programs.zsh.enable = true;
  users.mutableUsers = false;
  users.users.sspeaks = {
    shell = pkgs.zsh;
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    hashedPasswordFile = config.sops.secrets.sspeaks-password.path;
  };
}
