{
  config,
  lib,
  pkgs,
  ...
}:

let
  ids = import (
    pkgs.runCommandLocal "ids.nix" { } ''
      cat > $out <<EOF
      {
        gid = $(${lib.getExe' pkgs.uutils-coreutils-noprefix "id"} -g);
        uid = $(${lib.getExe' pkgs.uutils-coreutils-noprefix "id"} -u);
      }
      EOF
    ''
  );
in
{
  options = {
    user = {
      group = lib.mkOption {
        type = lib.types.str;
        default = "nix-on-droid";
        description = "Group name.";
      };
      gid = lib.mkOption {
        type = lib.types.int;
        default = ids.gid;
        defaultText = "$(id -g)";
        description = ''
          Gid.  This value should not be set manually except you know what you are doing.
        '';
      };
      home = lib.mkOption {
        type = lib.types.path;
        readOnly = true;
        description = "Path to home directory.";
      };
      shell = lib.mkOption {
        type = lib.types.path;
        default = lib.getExe pkgs.bash;
        defaultText = lib.literalExpression "${lib.getExe pkgs.bash}";
        description = "Path to login shell.";
      };
      userName = lib.mkOption {
        type = lib.types.str;
        default = "nix-on-droid";
        description = "User name.";
      };
      uid = lib.mkOption {
        type = lib.types.int;
        default = ids.uid;
        defaultText = "$(id -u)";
        description = ''
          Uid.  This value should not be set manually except you know what you are doing.
        '';
      };
    };
  };

  config = {
    environment.etc = {
      "group".text = ''
        root:x:0:
        ${config.user.group}:x:${toString config.user.gid}:${config.user.userName}
      '';
      "passwd".text = ''
        root:x:0:0:System administrator:${config.build.installationDir}/root:/bin/sh
        ${config.user.userName}:x:${toString config.user.uid}:${toString config.user.gid}:${config.user.userName}:${config.user.home}:${config.user.shell}
      '';
    };
    user = {
      home = "/data/data/com.termux.nix/files/home";
    };
  };
}
