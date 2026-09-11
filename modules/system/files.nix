{
  lib,
  pkgs,
  options,
  config,
  ...
}:

{
  options.environment = {
    etc = lib.mkOption {
      type = options.environment.files.type;
      default = { };
      example = lib.literalExpression ''
        { example-configuration-file = {
          source = "/nix/store/.../etc/dir/file.conf.example";
          mode = "0440";
        };
        }
      '';
      description = ''
        Set of files that have to be linked in {file}`/etc`.
      '';
    };
    files = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          {
            name,
            config,
            options,
            ...
          }:
          {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = ''
                  Whether this file should be generated. This
                  option allows specific files to be disabled.
                '';
              };
              target = lib.mkOption {
                type = lib.types.str;
                description = ''
                  Name of symlink. Defaults to the attribute
                  name.
                '';
              };
              text = lib.mkOption {
                default = null;
                type = lib.types.nullOr lib.types.lines;
                description = "Text of the file.";
              };
              source = lib.mkOption {
                type = lib.types.either lib.types.str lib.types.path;
                description = "Path of the source file.";
              };
              mode = lib.mkOption {
                type = lib.types.str;
                default = "symlink";
                example = "0600";
                description = ''
                  If set to something else than `symlink`,
                  the file is copied instead of symlinked, with the given
                  file mode.
                '';
              };
              uid = lib.mkOption {
                default = 0;
                type = lib.types.int;
                description = ''
                  UID of created file. Only takes effect when the file is
                  copied (that is, the mode is not 'symlink').
                '';
              };
              gid = lib.mkOption {
                default = 0;
                type = lib.types.int;
                description = ''
                  GID of created file. Only takes effect when the file is
                  copied (that is, the mode is not 'symlink').
                '';
              };
            };
            config = {
              target = lib.mkDefault name;
              source = lib.mkIf (config.text != null) (
                let
                  name' = lib.replaceStrings [ "/" ] [ "-" ] name;
                in
                lib.mkDerivedConfig options.text (pkgs.writeText name')
              );
            };
          }
        )
      );
      default = { };
      example = lib.literalExpression ''
        { "bin/sh" = {
          source = "/nix/store/.../bin/sh";
          mode = "0440";
        };
        }
      '';
      description = ''
        Set of files that have to be linked.
      '';
    };
  };

  config =
    let
      cfg = config.environment;
      enabledEtc = lib.filter (f: f.enable) (lib.attrValues cfg.etc);
      enabledFiles = lib.filter (f: f.enable) (lib.attrValues cfg.files);
      toSmfhFile = file: {
        inherit (file) uid gid;
        type =
          if
            ((file.mode == "symlink" || file.mode == "direct-symlink") && (!config.system.build.userlandBuild))
          then
            "symlink"
          else
            "copy";
        source = file.source;
        target = file.target;
        permissions = if (file.mode == "symlink" || file.mode == "direct-symlink") then null else file.mode;
        clobber = true;
      };
      smfhManifest = pkgs.writeText "smfh-manifest.json" (
        builtins.toJSON {
          version = 3;
          clobber_by_default = true;
          files =
            (lib.optionals (!config.system.build.userlandBuild) (
              [
                {
                  type = "symlink";
                  source = config.system.build.etc;
                  target = "/etc/static";
                }
              ]
              ++ map (
                file:
                toSmfhFile (
                  file
                  // {
                    source = "/etc/static/${file.target}";
                    target = "/etc/${file.target}";
                  }
                )
              ) enabledEtc
            ))
            ++ map (
              file:
              toSmfhFile (
                file
                // {
                  target =
                    "${lib.optionalString config.system.build.userlandBuild "@out@"}/"
                    + lib.removePrefix "/" file.target;
                }
              )
            ) enabledFiles;
        }
      );
    in
    {
      system.build = {
        etc = pkgs.linkFarm "etc" (
          map (f: {
            name = f.target;
            path = f.source;
          }) enabledEtc
        );
        inherit smfhManifest;
      };
      programs.switch-to-configuration.process-compose.config.processes.smfh.command =
        let
          stateDir = "${config.users.users.root.home}/.local/state/smfh";
          oldManifest = "${stateDir}/manifest.json";
          linker = lib.getExe pkgs.smfh;
        in
        ''
          ${lib.getExe' pkgs.coreutils "mkdir"} --parents "${stateDir}"
          if ${lib.getExe' pkgs.coreutils "test"} -f "${oldManifest}"; then
            ${linker} diff "${smfhManifest}" "${oldManifest}"
          else
            ${linker} activate "${smfhManifest}"
          fi
          if ! ${lib.getExe' pkgs.coreutils "cp"} "${smfhManifest}" "${oldManifest}.tmp"; then
            ${lib.getExe' pkgs.coreutils "rm"} --recursive --force "${stateDir}"
            ${lib.getExe' pkgs.coreutils "mkdir"} --parents "${stateDir}"
            ${lib.getExe' pkgs.coreutils "cp"} "${smfhManifest}" "${oldManifest}"
          else
            ${lib.getExe' pkgs.coreutils "mv"} "${oldManifest}.tmp" "${oldManifest}"
          fi
        '';
    };
}
