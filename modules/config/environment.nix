{
  lib,
  pkgs,
  options,
  config,
  ...
}:

let
  cfg = config.environment;
in
{
  options.environment = {
    variables = lib.mkOption {
      default = { };
      example = {
        EDITOR = "nvim";
        VISUAL = "nvim";
      };
      description = ''
        A set of environment variables used in the global environment.
        These variables will be set on shell initialisation (e.g. in /etc/profile).

        The value of each variable can be either a string or a list of
        strings.  The latter is concatenated, interspersed with colon
        characters.

        Setting a variable to `null` does nothing. You can override a
        variable set by another module to `null` to unset it.
      '';
      type = lib.types.attrsOf (
        lib.types.nullOr (
          lib.types.oneOf [
            (lib.types.listOf (
              lib.types.oneOf [
                lib.types.int
                lib.types.str
                lib.types.path
              ]
            ))
            lib.types.int
            lib.types.str
            lib.types.path
          ]
        )
      );
      apply =
        let
          toStr = v: if lib.isPath v then "${v}" else toString v;
        in
        attrs:
        lib.mapAttrs (n: v: if lib.isList v then lib.concatMapStringsSep ":" toStr v else toStr v) (
          lib.filterAttrs (n: v: v != null) attrs
        );
    };
    sessionVariables = lib.mkOption {
      inherit (options.environment.variables) type apply;
      default = { };
      description = "Environment variables to always set at login.";
    };
    profiles = lib.mkOption {
      default = [ ];
      description = ''
        A list of profiles used to setup the global environment.
      '';
      type = lib.types.listOf lib.types.str;
    };
    profileRelativeSessionVariables = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      example = {
        PATH = [ "/bin" ];
        MANPATH = [
          "/man"
          "/share/man"
        ];
      };
      description = ''
        Attribute set of environment variable used in the global
        environment. 

        Each attribute maps to a list of relative paths. Each relative
        path is appended to the each profile of
        {option}`environment.profiles` to form the content of
        the corresponding environment variable.
      '';
    };
    profileRelativeEnvVars = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      example = {
        PATH = [ "/bin" ];
        MANPATH = [
          "/man"
          "/share/man"
        ];
      };
      description = ''
        Attribute set of environment variable.  Each attribute maps to a list
        of relative paths.  Each relative path is appended to the each profile
        of {option}`environment.profiles` to form the content of the
        corresponding environment variable.
      '';
    };
    extraInit = lib.mkOption {
      default = "";
      description = ''
        Shell script code called during global environment initialisation
        after all variables and profileVariables have been set.
        This code is assumed to be shell-independent, which means you should
        stick to pure sh without sh word split.
      '';
      type = lib.types.lines;
    };
    homeBinInPath = lib.mkOption {
      description = ''
        Include ~/bin/ in $PATH.
      '';
      default = false;
      type = lib.types.bool;
    };
    localBinInPath = lib.mkOption {
      description = ''
        Add ~/.local/bin/ to $PATH
      '';
      default = false;
      type = lib.types.bool;
    };
    binsh = lib.mkOption {
      default = lib.getExe pkgs.bash;
      defaultText = lib.literalExpression "lib.getExe pkgs.bash";
      example = lib.literalExpression "lib.getExe pkgs.dash";
      type = lib.types.nullOr lib.types.path;
      visible = false;
      description = ''
        The shell executable that is linked system-wide to
        `/bin/sh`. Please note that NixOS assumes all
        over the place that shell to be Bash, so override the default
        setting only if you know exactly what you're doing.
      '';
    };
    usrbinenv = lib.mkOption {
      default = lib.getExe' pkgs.coreutils "env";
      defaultText = lib.literalExpression ''lib.getExe' pkgs.coreutils "env"'';
      example = lib.literalExpression ''lib.getExe' pkgs.busybox "env"'';
      type = lib.types.nullOr lib.types.path;
      visible = false;
      description = ''
        The {manpage}`env(1)` executable that is linked system-wide to
        `/usr/bin/env`.
      '';
    };
  };

  config = {
    environment = {
      sessionVariables = {
        HOME = config.users.users.nix-on-droid.home;
        USER = config.users.users.nix-on-droid.name;
        GC_NPROCS = 1;
      };
      profileRelativeEnvVars = config.environment.profileRelativeSessionVariables;
      # For resetting environment with `. /etc/set-environment` when needed
      # and discoverability (see motivation of #30418).
      etc.set-environment.source = config.system.build.setEnvironment;
      files = {
        "bin/sh".source = cfg.binsh;
        "usr/bin/env".source = cfg.usrbinenv;
      };
    };
    system.build =
      let
        absoluteVariables = lib.mapAttrs (n: lib.toList) (cfg.variables // cfg.sessionVariables);

        suffixedVariables = lib.flip lib.mapAttrs cfg.profileRelativeEnvVars (
          envVar: listSuffixes:
          lib.concatMap (profile: map (suffix: "${profile}${suffix}") listSuffixes) cfg.profiles
        );

        allVariables = lib.zipAttrsWith (n: lib.concatLists) [
          absoluteVariables
          suffixedVariables
        ];

        exportVariables = lib.mapAttrsToList (
          n: v: ''export ${n}="${lib.concatStringsSep ":" v}"''
        ) allVariables;

        stringifiedVariables = lib.mapAttrs (n: v: lib.concatStringsSep ":" v) allVariables;

        exportedEnvVars = lib.concatStringsSep "\n" exportVariables;
      in
      {
        environmentVariables = stringifiedVariables;
        setEnvironment = pkgs.writeText "set-environment" ''
          # DO NOT EDIT -- this file has been generated automatically.

          # Prevent this file from being sourced by child shells.
          export __NIXOS_SET_ENVIRONMENT_DONE=1

          ${exportedEnvVars}

          ${cfg.extraInit}

          ${lib.optionalString cfg.homeBinInPath ''
            # ~/bin if it exists overrides other bin directories.
            export PATH="$HOME/bin:$PATH"
          ''}

          ${lib.optionalString cfg.localBinInPath ''
            export PATH="$HOME/.local/bin:$PATH"
          ''}
        '';
      };
  };
}
