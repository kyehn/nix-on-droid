{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-proot.url = "github:NixOS/nixpkgs/49ee0e94463abada1de470c9c07bfc12b36dcf40";
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
    inputs@{
      nixpkgs,
      flake-parts,
      home-manager,
      ...
    }:
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
            inherit extraSpecialArgs home-manager-path pkgs;
            config.imports = modules;
            isFlake = true;
          });

        templates.default = {
          path = ./templates;
          description = "Example of Nix-on-Droid config";
        };
      };

      perSystem =
        {
          self',
          system,
          pkgs,
          ...
        }:
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

          formatter = pkgs.nixfmt-tree.override {
            runtimeInputs = [ pkgs.yamlfmt ];
            settings = {
              formatter.yamlfmt = {
                command = "yamlfmt";
                includes = [
                  "*.yaml"
                  "*.yml"
                ];
              };
            };
          };

          apps = {
            default = self'.apps.${system}.nix-on-droid;

            nix-on-droid = {
              type = "app";
              program = pkgs.lib.getExe pkgs.nix-on-droid;
            };
          };
        };
    };
}
