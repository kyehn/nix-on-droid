{
  config,
  lib,
  buildGoModule,
  runCommand,
  formats,
  process-compose,
}:

let
  base = buildGoModule (finalAttrs: {
    pname = "session-${finalAttrs.meta.mainProgram}";
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

    vendorHash = "sha256-0Z2gUJdWeVNEDFglaKo3zorNSbfUNWG8iHkDzB313Dw=";

    subPackages = [ "cmd/${finalAttrs.meta.mainProgram}" ];

    env.CGO_ENABLED = 0;

    meta.mainProgram = "login-inner";
  });
in
runCommand base.name
  {
    meta.mainProgram = base.meta.mainProgram;
    inherit base;
  }
  ''
    install -D --mode=0755 ${lib.getExe base} $out/bin/${base.meta.mainProgram}
    install -D --mode=0644 ${
      (formats.toml { }).generate "config.toml" {
        installation_dir = config.system.build.installationDir;
        user = {
          inherit (config.users.users.nix-on-droid) name home shell;
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
        first_run = config.system.build.bootstrapBuild;
      }
    } $out/etc/${base.meta.mainProgram}.toml
  ''
