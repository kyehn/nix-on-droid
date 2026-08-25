{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.system.build = {
    userlandBuild = lib.mkOption {
      type = lib.types.bool;
      default = false;
      internal = true;
      description = "Whether this is the build for the userland.";
    };
    flake.nix-on-droid = lib.mkOption {
      type = lib.types.str;
      default = "github:kyehn/nix-on-droid/unstable";
    };
    etc = lib.mkOption {
      type = lib.types.package;
      internal = true;
      description = "The derivation containing /etc files.";
    };
    setEnvironment = lib.mkOption {
      type = lib.types.path;
      internal = true;
    };
    nixos-rebuild = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nixos-rebuild-ng;
    };
    smfhManifest = lib.mkOption {
      type = lib.types.path;
      internal = true;
    };
    environmentVariables = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      internal = true;
    };
  };

  config = {
    environment = {
      files."bin/bash" = {
        source = lib.getExe (pkgs.login.override { inherit config; });
        mode = "0755";
      };
    }
    // (lib.optionalAttrs config.system.build.userlandBuild {
      sessionVariables.NIX_CONFIG = "experimental-features = nix-command flakes";
    });
  };
}
