{
  config,
  lib,
  pkgs,
  ...
}:

let
  etc' = lib.filter (f: f.enable) (lib.attrValues config.environment.etc);
  etc = pkgs.stdenvNoCC.mkDerivation {
    name = "etc";
    builder = ./make-etc.sh;
    preferLocalBuild = true;
    allowSubstitutes = false;
    sources = map (x: x.source) etc';
    targets = map (x: x.target) etc';
  };
  fileType = lib.types.submodule (
    { name, config, ... }:
    {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Whether this <filename>/etc</filename> file should be generated.  This
            option allows specific <filename>/etc</filename> files to be disabled.
          '';
        };
        target = lib.mkOption {
          type = lib.types.str;
          description = ''
            Name of symlink (relative to <filename>/etc</filename>).
            Defaults to the attribute name.
          '';
        };
        text = lib.mkOption {
          type = lib.types.nullOr lib.types.lines;
          default = null;
          description = "Text of the file.";
        };
        source = lib.mkOption {
          type = lib.types.path;
          description = "Path of the source file.";
        };
      };
      config = {
        target = lib.mkDefault name;
        source = lib.mkIf (config.text != null) (
          let
            name' = "etc-" + baseNameOf name;
          in
          lib.mkDefault (pkgs.writeText name' config.text)
        );
      };
    }
  );
in
{
  options = {
    environment = {
      etc = lib.mkOption {
        type = lib.types.loaOf fileType;
        default = { };
        example = lib.literalExpression ''
          {
            example-configuration-file = {
              source = "/nix/store/.../etc/dir/file.conf.example";
            };
            "default/useradd".text = "GROUP=100 ...";
          }
        '';
        description = ''
          Set of files that have to be linked in <filename>/etc</filename>.
        '';
      };
      etcBackupExtension = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = ".bak";
        description = ''
          Backup file extension.
          </para><para>
          If a file in <filename>/etc</filename> already exists and is not managed
          by Nix-on-Droid, the activation fails because we do not overwrite unknown
          files. When an extension is provided through this option, the original
          file will be moved in respect of the backup extension and the activation
          executes successfully.
        '';
      };
    };
  };

  config = {
    build = {
      inherit etc;
      activation.setUpEtc = ''
        $DRY_RUN_CMD bash ${./setup-etc.sh} /etc ${etc}/etc ${toString config.environment.etcBackupExtension}
      '';
    };
  };
}
