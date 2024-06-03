{
  description = "NixOS Config";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-24.05";
    nixos-hardware.url = "nixos-hardware";
    home-manager.url = "github:nix-community/home-manager/release-24.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    systems.url = "github:nix-systems/default-linux";
    sops-nix = {
      url = "github:/mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pogbot = {
      url = "github:sspeaks/pogbot";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spock = {
      url = "github:sspeaks/Spock-clip-trimmer";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = inputs@{ self, nixpkgs, home-manager, nixos-wsl, systems, ... }:
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
      packages = forEachSystem (pkgs: import ./packages {inherit pkgs;});
      nixosConfigurations = { 
        nixpi = lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            hosts/nixpi
          ];
        };
        NixOS-WSL = lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            hosts/nixosWSL
          ];
        };
        nixos-azure = lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            hosts/nixos-azure
          ];
        };
        vm = lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            hosts/vm
          ];
        };
      };
      homeConfigurations = {
        "sspeaks@nixpi" = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor.aarch64-linux;
          modules = [ home/sspeaks.nix ];
        };
        "sspeaks@NixOS-WSL" = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor.x86_64-linux;
          modules = [ home/sspeaks.nix ];
        };
      };
      formatter = forEachSystem (pkgs: pkgs.nixpkgs-fmt);
      overlays = import ./overlays.nix;
    };
}
