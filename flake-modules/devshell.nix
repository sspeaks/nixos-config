{
  perSystem = { pkgs, config, ... }: {
    devshells.default = {
      name = "nixos-config";
      packages = with pkgs; [ sops age ssh-to-age nix-output-monitor ];
      commands = [
        { name = "fmt"; help = "Format the tree"; command = "nix fmt"; }
        { name = "check"; help = "Run flake checks"; command = "nix flake check"; }
      ];
      devshell.startup.pre-commit-install.text = config.pre-commit.installationScript;
    };
  };
}
