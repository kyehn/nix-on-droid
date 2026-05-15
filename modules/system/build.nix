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
      default = "/data/data/com.termux.nix/files/usr";
      readOnly = true;
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
    environment = {
      files =
        let
          session-login = pkgs.session-login.override { inherit config; };
          session-login-inner = pkgs.session-login-inner.override { inherit config; };
        in
        {
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
