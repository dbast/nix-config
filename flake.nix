{
  description = "NixOS configurations for various systems including QNAP TS-433";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko/v1.11.0";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
      home-manager,
      disko,
      ...
    }:
    let
      si = self.sourceInfo;
    in
    {
      # Forward formatter output from treefmt-nix for all systems
      formatter = treefmt-nix.formatter;

      # Packages
      packages =
        nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ]
          (system: {
            dix = nixpkgs.legacyPackages.${system}.dix;
          });

      # Apps
      apps =
        nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ]
          (system: {
            dix = {
              type = "app";
              program = "${nixpkgs.legacyPackages.${system}.dix}/bin/dix";
              meta.mainProgram = "dix";
              meta.description = "Interactive disk space usage CLI tool";
            };
          });

      # NixOS configurations
      nixosConfigurations.qnas = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          disko.nixosModules.disko
          ./machines/qnas.nix
          ./disko/qnas.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.daniel = import ./users/daniel/home-manager.nix;
          }

          (
            { ... }:
            {
              system.configurationRevision = (si.rev or null);
            }
          )

        ];
        specialArgs = { inherit home-manager; };
      };
    };
}
