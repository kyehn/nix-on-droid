{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.users;
in
{
  options.users =
    let
      userOpts =
        { name, config, ... }:
        {
          options = {
            name = lib.mkOption {
              type = lib.types.passwdEntry lib.types.str;
              apply =
                x:
                assert (
                  lib.stringLength x < 32
                  || abort "Username '${x}' is longer than 31 characters which is not allowed!"
                );
                x;
              description = "The name of the user account.";
            };
            uid = lib.mkOption {
              type = lib.types.int;
              description = "The account UID.";
            };
            group = lib.mkOption {
              type = lib.types.str;
              apply =
                x:
                assert (
                  lib.stringLength x < 32
                  || abort "Group name '${x}' is longer than 31 characters which is not allowed!"
                );
                x;
              default = "";
              description = "The user's primary group.";
            };
            home = lib.mkOption {
              type = lib.types.passwdEntry lib.types.path;
              default = "/var/empty";
              description = "The user's home directory.";
            };
            shell = lib.mkOption {
              type = lib.types.nullOr (
                lib.types.either lib.types.shellPackage (lib.types.passwdEntry lib.types.path)
              );
              default = lib.getExe pkgs.bash;
              defaultText = lib.literalExpression "lib.getExe pkgs.bash";
              example = lib.literalExpression "lib.getExe pkgs.brush";
              apply =
                value:
                if value == null then
                  null
                else if lib.isDerivation value then
                  (if value ? shellPath then "${value}${value.shellPath}" else lib.getExe value)
                else
                  value;
              description = ''
                The path to the user's shell. Can use shell derivations,
                like `pkgs.bash`. 
              '';
            };
            packages = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [ ];
              example = lib.literalExpression "[ pkgs.firefox pkgs.thunderbird ]";
              description = ''
                The set of packages that should be made available to the user.
                This is in contrast to {option}`environment.systemPackages`,
                which adds packages to all users.
              '';
            };
          };
          config.name = lib.mkDefault name;
        };
      groupOpts =
        { name, config, ... }:
        {
          options = {
            name = lib.mkOption {
              type = lib.types.passwdEntry lib.types.str;
              description = "The name of the group.";
            };
            gid = lib.mkOption {
              type = lib.types.int;
              description = "The group GID.";
            };
          };
          config.name = lib.mkDefault name;
        };
    in
    {
      users = lib.mkOption {
        default = { };
        type = lib.types.attrsOf (lib.types.submodule userOpts);
        example = {
          alice = {
            uid = 1234;
            home = "/home/alice";
            group = "users";
            shell = "/bin/sh";
          };
        };
        description = ''
          Additional user accounts to be created automatically by the system.
          This can also be used to set options for root.
        '';
      };
      groups = lib.mkOption {
        default = { };
        example = {
          students.gid = 1001;
          hackers = { };
        };
        type = lib.types.attrsOf (lib.types.submodule groupOpts);
        description = ''
          Additional groups to be created automatically by the system.
        '';
      };
    };

  config = {
    users = {
      users = {
        root = {
          uid = config.ids.uids.root;
          home = "/root";
          group = "root";
        };
        nix-on-droid = {
          uid =
            if config.system.build.bootstrapBuild then
              65534
            else
              builtins.exec [
                "id"
                "-u"
              ];
          home = lib.mkDefault "/data/data/com.termux.nix/files/home";
          group = "nix-on-droid";
        };
      };
      groups = {
        root.gid = config.ids.gids.root;
        nix-on-droid.gid =
          if config.system.build.bootstrapBuild then
            65534
          else
            builtins.exec [
              "id"
              "-g"
            ];
      };
    };
    environment = {
      profiles = [
        "${config.users.users.nix-on-droid.home}/.nix-profile"
        "${config.users.users.nix-on-droid.home}/.local/state/nix/profile"
        "/etc/profiles/per-user/${config.users.users.nix-on-droid.name}"
      ];
      etc =
        (lib.mapAttrs' (
          _:
          { packages, name, ... }:
          {
            name = "profiles/per-user/${name}";
            value.source = pkgs.buildEnv {
              name = "user-environment";
              paths = packages;
              inherit (config.environment) pathsToLink extraOutputsToInstall;
              inherit (config.system.path) ignoreCollisions postBuild;
            };
          }
        ) (lib.filterAttrs (_: u: u.packages != [ ]) cfg.users))
        // {
          "group".text = ''
            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (name: { gid, ... }: "${name}:x:${toString gid}:") config.users.groups
            )}
          '';
          "passwd".text = ''
            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (
                name:
                {
                  uid,
                  group,
                  shell,
                  home,
                  ...
                }:
                let
                  g = config.users.groups.${group};
                in
                "${name}:x:${toString uid}:${toString g.gid}::${home}:${shell}"
              ) config.users.users
            )}
          '';
        };
    };
  };
}
