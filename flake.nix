{
  description = "NixOS configurations for various systems including QNAP TS-433";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # renovate: datasource=github-tags depName=nix-community/disko versioning=semver extractVersion=^v(?<version>.*)$
    disko.url = "github:nix-community/disko/v1.13.0";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      flake-parts,
      nixpkgs,
      treefmt-nix,
      home-manager,
      disko,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ treefmt-nix.flakeModule ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      perSystem =
        { pkgs, system, ... }:
        {
          treefmt = import ./treefmt.nix;

          packages = {
            inherit (pkgs) dix;
          }
          // (
            if pkgs.stdenv.hostPlatform.isLinux then
              {
                qnas-test = import ./tests/qnas-integration-test.nix {
                  inputs = { inherit nixpkgs home-manager disko; };
                  inherit system;
                };
              }
            else
              { }
          );
        };

      flake.nixosConfigurations.qnas = nixpkgs.lib.nixosSystem {
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
          {
            system.configurationRevision = self.sourceInfo.rev or null;
          }
        ];
        specialArgs = { inherit home-manager; };
      };
    };
}
