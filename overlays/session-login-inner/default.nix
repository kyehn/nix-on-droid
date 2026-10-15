{
  config,
  lib,
  buildGoModule,
  runCommand,
  formats,
  process-compose,
  nix,
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
        first_run = {
          enable = config.system.build.bootstrapBuild;
          environment = [
            {
              name = "GC_NPROCS";
              value = "1";
            }
            {
              name = "NIXOS_REBUILD_I_UNDERSTAND_THE_CONSEQUENCES_PLEASE_BREAK_MY_SYSTEM";
              value = "1";
            }
          ];
          commands = [
            {
              argv0 = lib.getExe' nix "nix-env";
              argv = [
                "--switch-profile"
                "/nix/var/nix/profiles/system"
              ];
            }
            {
              argv0 = lib.getExe nix;
              argv = [
                "--extra-experimental-features"
                "nix-command"
                "--extra-experimental-features"
                "flakes"
                "flake"
                "new"
                "${config.users.users.nix-on-droid.home}/.config/nix-on-droid/template"
                "--template"
                "${config.system.build.flake.nix-on-droid}"
              ];
            }
            {
              argv0 = lib.getExe nix;
              argv = [
                "--extra-experimental-features"
                "nix-command"
                "--extra-experimental-features"
                "flakes"
                "run"
                "nixpkgs#nixos-rebuild-ng"
                "--"
                "switch"
                "--flake"
                "${config.users.users.nix-on-droid.home}/.config/nix-on-droid/template#default"
                "--impure"
                "--accept-flake-config"
                "--verbose"
                "--print-build-logs"
                "--show-trace"
                "--use-substitutes"
              ];
            }
          ];
          fallback_shell = config.system.build.installationDir + "/bin/sh";
        };
      }
    } $out/etc/${base.meta.mainProgram}.toml
  ''
