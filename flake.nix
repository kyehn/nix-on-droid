{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      flake-parts,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = builtins.filter (system: system != "x86_64-darwin") nixpkgs.lib.systems.flakeExposed;

      flake = {
        lib.nixOnDroidConfiguration =
          {
            system ? builtins.currentSystem,
            pkgs ? (import nixpkgs { inherit system; }),
            lib ? pkgs.lib,
            modules ? [ ],
            extraSpecialArgs ? { },
            ...
          }:
          (import ./modules {
            inherit extraSpecialArgs inputs;
            pkgs = pkgs.extend (import ./overlays { inherit inputs; });
            configuration.imports = modules;
          });

        templates.default = {
          path = ./template;
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
            nixfmtPackage = pkgs.nixfmt-rs;
            runtimeInputs = with pkgs; [
              yamlfmt
              shfmt
              rustfmt
              taplo
              ruff
              go
              gofumpt
              gotools
              revive
            ];
            settings.formatter = {
              yamlfmt = {
                command = "yamlfmt";
                includes = [
                  "*.yaml"
                  "*.yml"
                ];
              };
              shfmt = {
                command = "shfmt";
                options = [ "-w" ];
                includes = [
                  "*.sh"
                  "*.bash"
                  "*.envrc"
                  "*.envrc.*"
                ];
              };
              rustfmt = {
                command = "rustfmt";
                options = [
                  "--config"
                  "skip_children=true"
                  "--edition"
                  "2024"
                  "--style-edition"
                  "2024"
                ];
                includes = [ "*.rs" ];
              };
              taplo = {
                command = "taplo";
                options = [ "format" ];
                includes = [ "*.toml" ];
              };
              ruff = {
                command = "ruff";
                options = [ "format" ];
                includes = [
                  "*.py"
                  "*.pyi"
                ];
              };
              gofmt = {
                command = "gofmt";
                options = [ "-w" ];
                includes = [ "*.go" ];
                excludes = [ "vendor/*" ];
              };
              gofumpt = {
                command = "gofumpt";
                options = [
                  "-e"
                  "-extra"
                  "-w"
                ];
                includes = [ "*.go" ];
                excludes = [ "vendor/*" ];
              };
              goimports = {
                command = "goimports";
                options = [
                  "-e"
                  "-w"
                ];
                includes = [ "*.go" ];
                excludes = [ "vendor/*" ];
              };
              revive = {
                command = "revive";
                options = [
                  "-config"
                  ./tests/.revive.toml
                  "-set_exit_status"
                ];
                includes = [ "*.go" ];
                excludes = [ "vendor/*" ];
              };
            };
          };
        };
    };
}
