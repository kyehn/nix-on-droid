{
  config,
  lib,
  pkgs,
  home-manager-path,
  ...
}:

let
  extendedLib = import (home-manager-path + "/modules/lib/stdlib-extended.nix") lib;
  hmModule = lib.types.submoduleWith {
    specialArgs = {
      lib = extendedLib;
    }
    // config.home-manager.extraSpecialArgs;
    modules = [
      (
        { ... }:
        {
          imports = import (home-manager-path + "/modules/modules.nix") {
            inherit pkgs;
            lib = extendedLib;
            useNixpkgsModule = !config.home-manager.useGlobalPkgs;
          };
          config = {
            submoduleSupport.enable = true;
            submoduleSupport.externalPackageInstall = config.home-manager.useUserPackages;
            home.username = config.user.userName;
            home.homeDirectory = config.user.home;
          };
        }
      )
    ]
    ++ config.home-manager.sharedModules;
  };
in
{
  options = {
    home-manager = {
      backupFileExtension = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "backup";
        description = ''
          On activation move existing files by appending the given
          file extension rather than exiting with an error.
        '';
      };
      overwriteBackup = lib.mkEnableOption "";
      config = lib.mkOption {
        type = lib.types.nullOr hmModule;
        default = null;
        # Prevent the entire submodule being included in the documentation.
        visible = "shallow";
        description = ''
          Home Manager configuration, see
          <link xlink:href="https://nix-community.github.io/home-manager/options.html" />.
        '';
      };
      extraSpecialArgs = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        example = lib.literalExpression "{ inherit emacs-overlay; }";
        description = ''
          Extra <literal>specialArgs</literal> passed to Home Manager. This
          option can be used to pass additional arguments to all modules.
        '';
      };
      sharedModules = lib.mkOption {
        type = lib.types.listOf lib.types.raw;
        default = [ ];
        example = lib.literalExpression "[ { home.packages = [ nixpkgs-fmt ]; } ]";
        description = ''
          Extra modules.
        '';
      };
      useGlobalPkgs = lib.mkEnableOption ''
        using the system configuration's <literal>pkgs</literal>
        argument in Home Manager. This disables the Home Manager
        options <option>nixpkgs.*</option>
      '';
      useUserPackages =
        lib.mkEnableOption ''
          installation of user packages through the
          <option>environment.packages</option> option.
        ''
        // {
          default = true;
        };
    };
  };

  config = lib.mkIf (config.home-manager.config != null) {
    inherit (config.home-manager.config) assertions warnings;
    build = {
      activationBefore = lib.mkIf config.home-manager.useUserPackages {
        setPriorityHomeManagerPath = ''
          if nix-env -q | grep '^home-manager-path$'; then
            $DRY_RUN_CMD nix-env $VERBOSE_ARG --set-flag priority 120 home-manager-path
          fi
        '';
      };
      activationAfter.homeManager = lib.concatStringsSep " " (
        (lib.optional (
          config.home-manager.backupFileExtension != null
        ) "HOME_MANAGER_BACKUP_EXT='${config.home-manager.backupFileExtension}'")
        ++ (lib.optional config.home-manager.overwriteBackup "HOME_MANAGER_BACKUP_OVERWRITE=1")
        ++ [ "${config.home-manager.config.home.activationPackage}/activate" ]
      );
    };
    environment.packages = lib.mkIf config.home-manager.useUserPackages config.home-manager.config.home.packages;
    # home-manager has a quirk redefining the profile location
    # to "/etc/profiles/per-user/${config.home-manager.username}" if useUserPackages is on.
    # https://github.com/nix-community/home-manager/blob/0006da1381b87844c944fe8b925ec864ccf19348/modules/home-environment.nix#L414
    # Fortunately, it's not that hard to us to workaround with just a symlink.
    environment.etc = lib.mkIf config.home-manager.useUserPackages {
      "profiles/per-user/${config.user.userName}".source = "${config.user.home}/.nix-profile";
    };
  };
}
