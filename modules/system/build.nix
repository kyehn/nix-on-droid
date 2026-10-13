{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.system.build = {
    bootstrapBuild = lib.mkOption {
      type = lib.types.bool;
      default = false;
      internal = true;
      description = "Whether this is the build for the bootstrap zip ball.";
    };
    installationDir = lib.mkOption {
      type = lib.types.path;
      default = "/data/data/com.termux/files/usr";
      description = "Base directory for Nix-on-Droid installation.";
    };
    proot = {
      bind = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
      };
      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Arguments passed to the proot executable.";
      };
    };
    flake.nix-on-droid = lib.mkOption {
      type = lib.types.str;
      default = "github:kyehn/nix-on-droid/unstable";
    };
    etc = lib.mkOption {
      type = lib.types.package;
      internal = true;
      description = "The derivation containing /etc files.";
    };
    setEnvironment = lib.mkOption {
      type = lib.types.path;
      internal = true;
    };
    nixos-rebuild = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nixos-rebuild-ng;
    };
    smfhManifest = lib.mkOption {
      type = lib.types.path;
      internal = true;
    };
    environmentVariables = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      internal = true;
    };
  };

  config = {
    environment =
      let
        session-login = pkgs.session-login.override { inherit config; };
        session-login-inner = pkgs.session-login-inner.override { inherit config; };
      in
      {
        files = {
          "bin/${pkgs.session-login.meta.mainProgram}" = {
            source = lib.getExe session-login;
            mode = "0755";
          };
          "bin/${pkgs.session-login-inner.meta.mainProgram}.new" = {
            source = lib.getExe session-login-inner;
            mode = "0755";
          };
          "bin/${pkgs.proot-termux.meta.mainProgram}.new" = {
            source = lib.getExe pkgs.proot-termux;
            mode = "0755";
          };
        };
        etc = {
          "${pkgs.session-login.meta.mainProgram}.toml".source =
            let
              proot_binary_path =
                config.system.build.installationDir + "/bin/" + pkgs.proot-termux.meta.mainProgram;
              login_inner_binary_path =
                config.system.build.installationDir + "/bin/" + pkgs.session-login-inner.meta.mainProgram;
            in
            (pkgs.formats.toml { }).generate "config.toml" {
              inherit login_inner_binary_path;
              installation_dir = config.system.build.installationDir;
              pending_artifacts = [
                proot_binary_path
                login_inner_binary_path
              ];
              user = {
                name = config.users.users.nix-on-droid.name;
                home = config.users.users.nix-on-droid.home;
              };
              proot = {
                bind = config.system.build.proot.bind;
                extra_args = config.system.build.proot.extraArgs;
                binary_path = proot_binary_path;
              };
            };
          "${pkgs.session-login-inner.meta.mainProgram}.toml".source =
            (pkgs.formats.toml { }).generate "config.toml"
              {
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
                  binary_path = lib.getExe pkgs.process-compose;
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
                      argv0 = lib.getExe' pkgs.nix "nix-env";
                      argv = [
                        "--switch-profile"
                        "/nix/var/nix/profiles/system"
                      ];
                    }
                    {
                      argv0 = lib.getExe pkgs.nix;
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
                      argv0 = lib.getExe pkgs.nix;
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
              };
        };
      }
      // (lib.optionalAttrs config.system.build.bootstrapBuild {
        sessionVariables.NIX_CONFIG = "experimental-features = nix-command flakes";
      });
    system.build.proot = {
      bind =
        map
          (
            s:
            let
              parts = lib.splitString ":" s;
            in
            {
              host_path = builtins.elemAt parts 0;
              guest_location = builtins.elemAt parts 1;
            }
          )
          [
            "${config.system.build.installationDir}/nix:/nix"
            "${config.system.build.installationDir}/root:/root"
            "${config.system.build.installationDir}/run:/run"
            "${config.system.build.installationDir}/bin:/bin!"
            "${config.system.build.installationDir}/etc:/etc!"
            "${config.system.build.installationDir}/tmp:/tmp"
            "${config.system.build.installationDir}/usr:/usr"
            "${config.system.build.installationDir}/var:/var"
            "${config.system.build.installationDir}/dev/shm:/dev/shm"
            "/dev/pts:/dev/pts"
            "${config.system.build.installationDir}${pkgs.writeText "fakeProcStat" ''
              btime 0
            ''}:/proc/stat"
            "${config.system.build.installationDir}${pkgs.writeText "fakeProcUptime" ''
              0.00 0.00
            ''}:/proc/uptime"
          ];
      extraArgs = [
        "--link2symlink"
        "--sysvipc"
        "--ashmem-memfd"
        "--kernel-release=5.4.254"
      ];
    };
  };
}
