{
  config,
  lib,
  buildGoModule,
  process-compose,
  formats,
}:

buildGoModule (finalAttrs: {
  pname = "switch-to-configuration";
  version = "0.1.0";
  __structuredAttrs = true;
  strictDeps = true;

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./go.sum
      ./go.mod
      ./cmd
    ];
  };

  vendorHash = "sha256-/Ox7fGsUo1dORSqxuuFTbKb89Y/ZjTlEwpBLqcAVfDk=";

  subPackages = [ "cmd/switch-to-configuration" ];

  env.CGO_ENABLED = 0;

  preBuild = ''
    cp ${
      (formats.toml { }).generate "config.toml" {
        installation_dir = config.system.build.installationDir;
        process_compose = {
          enable =
            let
              processes = config.programs.switch-to-configuration.process-compose.config.processes;
            in
            (processes != null && processes != { });
          binary_path = lib.getExe process-compose;
          config_path =
            (formats.yaml { }).generate "process-compose.yaml"
              config.programs.switch-to-configuration.process-compose.config;
          extra_args = [
            "--disable-dotenv"
            "--no-server"
            "--read-only"
            "-t=false"
          ];
        };
      }
    } cmd/switch-to-configuration/config.toml
  '';

  meta.mainProgram = "switch-to-configuration";
})
