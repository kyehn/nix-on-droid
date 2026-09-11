{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.home-manager;
in
{
  config = {
    programs.switch-to-configuration.process-compose.config.processes.home-manager = {
      environment = [
        "HOME=${config.users.users.root.home}"
        "USER=${config.users.users.root.name}"
        "PATH=${
          lib.makeBinPath [
            pkgs.bash
            pkgs.coreutils
            pkgs.findutils
            pkgs.gnugrep
            pkgs.gnused
            pkgs.gawk
          ]
        }"
        "TERM=xterm-256color"
        "QT_QPA_PLATFORM=offscreen"
        "NIX_STATE_DIR=/nix/var/nix"
        "XDG_STATE_HOME=${config.users.users.root.home}/.local/state"
        "XDG_DATA_HOME=${config.users.users.root.home}/.local/share"
        "XDG_CACHE_HOME=${config.users.users.root.home}/.cache"
        "LANG=C.UTF-8"
        "SHELL=${lib.getExe pkgs.bashNonInteractive}"
      ]
      ++ (lib.optional (
        cfg.backupFileExtension != null
      ) "HOME_MANAGER_BACKUP_EXT=${cfg.backupFileExtension}")
      ++ (lib.optional cfg.overwriteBackup "HOME_MANAGER_BACKUP_OVERWRITE=1");
      command = "${cfg.users.root.home.activationPackage}/activate";
    };
  };
}
