{
  description = "NixOS RPi4 Config";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-23.05";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/release-23.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    
    systems.url = "github:nix-systems/default-linux";
  };
  outputs = inputs@{ self, nixpkgs, nixpkgs-unstable, home-manager, systems, ... }:
    let
      inherit (self) outputs;
      lib = nixpkgs.lib;
      forEachSystem = f: lib.genAttrs (import systems) (system: f pkgsFor.${system});
    pkgsFor = lib.genAttrs (import systems) (
      system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        }
    );
    in
    {
      nixosConfigurations = {
        nixpi = lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            hosts/nixpi
          ];
        };
      };
      homeConfigurations = {
        "sspeaks@nixpi" = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor.aarch64-linux;
          modules = [ home/sspeaks.nix ];
        };
      };
      formatter = forEachSystem (pkgs: pkgs.nixpkgs-fmt);
      overlays = {};
    };
}
