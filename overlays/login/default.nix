{
  config,
  lib,
  stdenvNoCC,
  formats,
  buildGoModule,
  process-compose,
  nix,
}:

buildGoModule (finalAttrs: {
  pname = "login";
  version = "0.1.0";
  __structuredAttrs = true;
  strictDeps = true;

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./go.mod
      ./go.sum
      ./cmd
    ];
  };

  vendorHash = "sha256-QjwNcCHVuQtGB0kyy/Q3BXlwR+pkwZ3sq9XgrzkS2bQ=";

  subPackages = [ "cmd/login" ];

  env.CGO_ENABLED = 0;

  preBuild = ''
    cp ${
      (formats.toml { }).generate "config.toml" {
        user = {
          inherit (config.users.users.root) name home shell;
        };
        environment = lib.mapAttrsToList (name: value: {
          inherit name value;
        }) config.system.build.environmentVariables;
        process_compose = {
          enable =
            let
              processes = config.programs.process-compose.config.processes;
            in
            (processes != null && processes != { });
          binary_path = lib.getExe process-compose;
          config_path = config.programs.process-compose.configFile;
          extra_args = [
            "--disable-dotenv"
            "--no-server"
            "--read-only"
            "-t=false"
          ];
        };
      }
    } cmd/login/config.toml
  '';

  meta.mainProgram = "login";
})
