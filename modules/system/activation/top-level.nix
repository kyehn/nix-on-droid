{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.system.build.toplevel = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
  };

  config.system.build.toplevel =
    (pkgs.linkFarm "system" [
      {
        name = "sw";
        path = config.system.path;
      }
      {
        name = "etc";
        path = config.system.build.etc;
      }
      {
        name = "nixos-version";
        path = pkgs.writeText "nixos-version" config.system.nixos.label;
      }
      {
        name = "system";
        path = pkgs.writeText "system" pkgs.stdenv.hostPlatform.system;
      }
    ]).overrideAttrs
      (oldAttrs: {
        buildCommand = oldAttrs.buildCommand + ''
          install -D --mode=0755 ${lib.getExe pkgs.switch-to-configuration} bin/switch-to-configuration
          install -D --mode=0644 ${
            (pkgs.formats.toml { }).generate "config.toml" {
              installation_dir = config.system.build.installationDir;
              process_compose = {
                enable =
                  let
                    processes = config.programs.switch-to-configuration.process-compose.config.processes;
                  in
                  (processes != null && processes != { });
                binary_path = lib.getExe pkgs.process-compose;
                config_path =
                  (pkgs.formats.yaml { }).generate "process-compose.yaml"
                    config.programs.switch-to-configuration.process-compose.config;
                extra_args = [
                  "--disable-dotenv"
                  "--no-server"
                  "--read-only"
                  "-t=false"
                ];
              };
            }
          } switch-to-configuration.toml
        '';
      });
}
