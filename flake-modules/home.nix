{ inputs, self, ... }:
let
  pkgsFor = system: import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
    overlays = import ../overlays.nix;
  };
  mkHome = system: modules:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = pkgsFor system;
      extraSpecialArgs = { inherit inputs; outputs = self; };
      inherit modules;
    };
in
{
  flake.homeConfigurations = {
    "sspeaks@NixOS-WSL" = mkHome "x86_64-linux" [ ../home/sspeaks.nix ../home/features/sops ];
    "sspeaks@blog" = mkHome "x86_64-linux" [ ../home/sspeaks-blog.nix ];
    "sspeaks@darwin" = mkHome "aarch64-darwin" [ ../home/sspeaks.nix ../home/features/sops ];
    "sspeaks@aarch64-linux" = mkHome "aarch64-linux" [ ../home/sspeaks.nix ../home/features/sops ];
  };
}
