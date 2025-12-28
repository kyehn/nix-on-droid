{
  config,
  lib,
  ...
}:

let
  defaultNixpkgsBranch = "nixpkgs-unstable";
  defaultNixOnDroidBranch = "unstable";
  defaultNixpkgsChannel = "https://nixos.org/channels/${defaultNixpkgsBranch}";
  defaultNixOnDroidChannel = "https://github.com/kyehn/nix-on-droid/archive/${defaultNixOnDroidBranch}.tar.gz";
  defaultNixpkgsFlake = "github:NixOS/nixpkgs/${defaultNixpkgsBranch}";
  defaultNixOnDroidFlake = "github:kyehn/nix-on-droid/${defaultNixOnDroidBranch}";
in
{
  options = {
    build = {
      channel = {
        nixpkgs = lib.mkOption {
          type = lib.types.str;
          default = defaultNixpkgsChannel;
          description = "Channel URL for nixpkgs.";
        };
        nix-on-droid = lib.mkOption {
          type = lib.types.str;
          default = defaultNixOnDroidChannel;
          description = "Channel URL for Nix-on-Droid.";
        };
      };
      flake = {
        nixpkgs = lib.mkOption {
          type = lib.types.str;
          default = defaultNixpkgsFlake;
          description = "Flake URL for nixpkgs.";
        };
        nix-on-droid = lib.mkOption {
          type = lib.types.str;
          default = defaultNixOnDroidFlake;
          description = "Flake URL for Nix-on-Droid.";
        };
        inputOverrides = lib.mkEnableOption "" // {
          description = ''
            Whether to override the standard input URLs in the initial <filename>flake.nix</filename>.
          '';
        };
      };
    };
  };

  config = {
    build = {
      initialBuild = true;
      flake.inputOverrides =
        config.build.flake.nixpkgs != defaultNixpkgsFlake
        || config.build.flake.nix-on-droid != defaultNixOnDroidFlake;
    };
    # /etc/group and /etc/passwd need to be build on target machine because
    # uid and gid need to be determined.
    environment.etc = {
      "group".enable = false;
      "passwd".enable = false;
      "UNINTIALISED".text = "";
    };
  };
}
