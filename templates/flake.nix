{
  description = "Example of Nix-on-Droid config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-on-droid = {
      url = "github:kyehn/nix-on-droid/unstable";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-on-droid,
    }:
    {

      nixOnDroidConfigurations.default = nix-on-droid.lib.nixOnDroidConfiguration {
        pkgs = import nixpkgs { system = "aarch64-linux"; };
        modules = [ ./nix-on-droid.nix ];
      };

    };
}
