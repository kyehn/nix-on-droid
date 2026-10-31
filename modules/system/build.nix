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
      description = "Base directory for Nix-on-Droid installation.";
    };
    proot = {
      package = lib.mkOption {
        type = lib.types.package;
        default = if pkgs.stdenv.targetPlatform.isAarch64 then pkgs.fake-chroot-ng else pkgs.proot-termux;
      };
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
        files."bin/${pkgs.session-login.meta.mainProgram}" = {
          source = lib.getExe session-login;
          mode = "0755";
        };
        etc = {
          "UNINTIALISED" = {
            text = "";
            mode = "0644";
          };
          "${pkgs.session-login.meta.mainProgram}.toml" = {
            source =
              let
                proot_binary_path =
                  (lib.removeSuffix "/" config.system.build.installationDir)
                  + (lib.getExe config.system.build.proot.package);
              in
              (pkgs.formats.toml { }).generate "config.toml" {
                login_inner_binary_path = lib.getExe session-login-inner;
                installation_dir = config.system.build.installationDir;
                pending_artifacts = [ ];
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
            mode = "0644";
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
              parts = lib.splitString ":" (
                if (config.system.build.proot.package.meta.mainProgram == "chroot-ng") then
                  lib.removeSuffix "!" s
                else
                  s
              );
            in
            {
              host_path = builtins.elemAt parts 0;
              guest_location = builtins.elemAt parts 1;
            }
          )
          (
            [
              "${config.system.build.installationDir}/nix:/nix"
              "${config.system.build.installationDir}/root:/root"
              "${config.system.build.installationDir}/run:/run"
              "${config.system.build.installationDir}/bin:/bin!"
              "${config.system.build.installationDir}/etc:/etc!"
              "${config.system.build.installationDir}/tmp:/tmp"
              "${config.system.build.installationDir}/usr:/usr"
              "${config.system.build.installationDir}/var:/var"
            ]
            ++ lib.optionals (config.system.build.proot.package.meta.mainProgram == "chroot-ng") [
              "${config.system.build.installationDir}/.l2s:/.l2s"
            ]
            ++ lib.optionals (config.system.build.proot.package.meta.mainProgram == "proot") [
              "${config.system.build.installationDir}/dev/shm:/dev/shm"
              "/dev/pts:/dev/pts"
              "${config.system.build.installationDir}${pkgs.writeText "fakeProcStat" ''
                btime 0
              ''}:/proc/stat"
              "${config.system.build.installationDir}${pkgs.writeText "fakeProcUptime" ''
                0.00 0.00
              ''}:/proc/uptime"
            ]
          );
      extraArgs =
        if config.system.build.proot.package.meta.mainProgram == "chroot-ng" then
          [
            "--share-abstract-sockets"
            "--shared-proc"
            "--no-ptrace"
            "--link2symlink"
            "--work-dir"
            config.users.users.nix-on-droid.home
          ]
        else
          [
            "--link2symlink"
            "--sysvipc"
            "--ashmem-memfd"
            "--kernel-release=5.4.254"
          ];
    };
  };
}
