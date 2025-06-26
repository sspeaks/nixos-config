{
  description = "NixOS Config";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    determinate = {
      url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    systems = {
      url = "github:nix-systems/default";
    };
    sops-nix = {
      url = "github:/mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pogbot = {
      url = "github:sspeaks/clipbot";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spock = {
      url = "github:sspeaks/Spock-clip-trimmer";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim/nixos-25.05";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
    factorio = {
      url = "github:sspeaks/factorio-server-nix/space_age";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    boggle = {
      url = "github:sspeaks/boggle-sovler";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-apple-silicon = {
      url = "github:tpwrules/nixos-apple-silicon";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-raspberrypi = {
	url = "github:nvmd/nixos-raspberrypi/main";
};
  };
  outputs = inputs@{ self, nixpkgs, home-manager, systems, nixos-raspberrypi, ... }:
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
      packages = forEachSystem (pkgs: import ./packages { inherit pkgs; });
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
        NixOS-WSL-work = lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            hosts/nixosWSL-work
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
        asahi = lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            hosts/asahi
          ];
        };
        nixpi5 = nixos-raspberrypi.lib.nixosSystem {
          specialArgs = { inherit nixos-raspberrypi inputs outputs; };
          modules = [
            hosts/nixpi5
            ({...}: {
imports = with nixos-raspberrypi.nixosModules; [
            raspberry-pi-5.base 
          ];
})
];
        };
      };
      homeConfigurations = {
        "sspeaks@NixOS-WSL" = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor.x86_64-linux;
          extraSpecialArgs = { inherit inputs; };
          modules = [ home/sspeaks.nix ];
        };
        "sspeaks@blog" = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor.x86_64-linux;
          extraSpecialArgs = { inherit inputs; };
          modules = [ home/sspeaks-blog.nix ];
        };
        "sspeaks@darwin" = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor.aarch64-darwin;
          extraSpecialArgs = { inherit inputs; };
          modules = [ home/sspeaks.nix ];
        };

      };
      formatter = forEachSystem (pkgs: pkgs.nixpkgs-fmt);
      overlays = import ./overlays.nix;
    };
nixConfig = {
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };
}
