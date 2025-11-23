{
  description = "Nix-enabled environment for your Android device";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nixpkgs-proot-termux.url = "github:NixOS/nixpkgs/49ee0e94463abada1de470c9c07bfc12b36dcf40";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-parts,
      home-manager,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.systems.flakeExposed;

      flake = {
        lib.nixOnDroidConfiguration =
          {
            pkgs,
            modules ? [ ],
            extraSpecialArgs ? { },
            home-manager-path ? home-manager.outPath,
          }:
          (import ./modules {
            targetSystem = pkgs.stdenv.hostPlatform.system;
            inherit extraSpecialArgs home-manager-path pkgs;
            config.imports = modules;
            isFlake = true;
          });

        templates = {
          default = self.templates.minimal;

          minimal = {
            path = ./templates/minimal;
            description = "Minimal example of Nix-on-Droid system config.";
          };
        };
      };
      perSystem =
        { system, pkgs, ... }:
        {
          _module.args.pkgs = import nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
              allowAliases = false;
              warnUndeclaredOptions = true;
            };
            overlays = [
              (import ./overlays { inherit inputs; })
            ];
          };

          legacyPackages = pkgs;

          formatter = pkgs.nixfmt-tree;

          apps = {
            default = self.apps.${system}.nix-on-droid;

            nix-on-droid = {
              type = "app";
              program = pkgs.lib.getExe pkgs.nix-on-droid;
            };

            deploy = {
              type = "app";
              program = pkgs.lib.getExe pkgs.deploy;
            };
          };
        };
    };
}
