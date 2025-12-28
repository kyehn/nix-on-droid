{
  config,
  lib,
  pkgs,
  ...
}:

{
  options = {
    environment = {
      binSh = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        description = "Path to <filename>/bin/sh</filename> executable.";
      };
      usrBinEnv = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        description = "Path to <filename>/usr/bin/env</filename> executable.";
      };
    };
  };

  config = {
    build.activationBefore = {
      linkBinSh = ''
        $DRY_RUN_CMD mkdir $VERBOSE_ARG --parents /bin
        $DRY_RUN_CMD ln $VERBOSE_ARG --symbolic --force ${config.environment.binSh} /bin/.sh.tmp
        $DRY_RUN_CMD mv $VERBOSE_ARG /bin/.sh.tmp /bin/sh
      '';
      linkUsrBinEnv = ''
        $DRY_RUN_CMD mkdir $VERBOSE_ARG --parents /usr/bin
        $DRY_RUN_CMD ln $VERBOSE_ARG --symbolic --force ${config.environment.usrBinEnv} /usr/bin/.env.tmp
        $DRY_RUN_CMD mv $VERBOSE_ARG /usr/bin/.env.tmp /usr/bin/env
      '';
    };
    environment = {
      binSh = lib.getExe' pkgs.bashInteractive "sh";
      usrBinEnv = lib.getExe' pkgs.uutils-coreutils-noprefix "env";
    };
  };
}
