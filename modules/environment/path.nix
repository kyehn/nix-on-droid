{
  config,
  lib,
  pkgs,
  ...
}:

{
  options = {
    environment = {
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "List of packages to be installed as user packages.";
      };
      path = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        internal = true;
        description = "Derivation for installing user packages.";
      };
      extraOutputsToInstall = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [
          "doc"
          "info"
          "devdoc"
        ];
        description = "List of additional package outputs to be installed as user packages.";
      };
    };
  };

  config = {
    build.activation.installPackages = ''
      if [[ -e "${config.user.home}/.nix-profile/manifest.json" ]]; then
        # manual removal and installation as two non-atomical steps is required
        # because of https://github.com/NixOS/nix/issues/6349
        nix_previous="$(command -v nix)"
        nix profile list \
          | grep 'nix-on-droid-path$' \
          | cut -d ' ' -f 4 \
          | xargs -t $DRY_RUN_CMD nix profile remove $VERBOSE_ARG
        $DRY_RUN_CMD $nix_previous profile install ${config.environment.path}
        unset nix_previous
      else
        $DRY_RUN_CMD nix-env --install ${config.environment.path}
      fi
    '';
    environment = {
      packages = [
        (pkgs.callPackage ../../overlays/nix-on-droid { nix = config.nix.package; })
        pkgs.bash
        pkgs.cacert
        pkgs.uutils-coreutils-noprefix
        pkgs.less # since nix tools really want a pager available, #27
        config.nix.package
      ];
      path = pkgs.buildEnv {
        name = "nix-on-droid-path";
        paths = config.environment.packages;
        inherit (config.environment) extraOutputsToInstall;
        meta = {
          description = "Environment of packages installed through Nix-on-Droid.";
        };
      };
    };
  };
}
