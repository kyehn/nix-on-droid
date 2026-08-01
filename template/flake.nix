{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    nix-on-droid = {
      url = "github:kyehn/nix-on-droid/unstable";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
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
      nix-on-droid,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.systems.flakeExposed;

      perSystem =
        {
          pkgs,
          system,
          ...
        }:
        {
          _module.args.pkgs = import nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
              allowAliases = false;
              warnUndeclaredOptions = true;
              microsoftVisualStudioLicenseAccepted = true;
            };
          };
        };
      flake = {
        nixosConfigurations.default = nix-on-droid.lib.nixOnDroidConfiguration {
          extraSpecialArgs = { inherit inputs; };
          modules = [
            "${inputs.nix-on-droid}/modules/home-manager.nix"
            "${inputs.home-manager}/nixos/common.nix"
            ./nix-on-droid.nix
          ];
        };
      };
    };
}
