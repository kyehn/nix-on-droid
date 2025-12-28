{
  lib,
  ...
}:

{
  options = {
    build = {
      initialBuild = lib.mkOption {
        type = lib.types.bool;
        default = false;
        internal = true;
        description = ''
          Whether this is the initial build for the bootstrap zip ball.
          Should not be enabled manually, see
          <filename>initial-build.nix</filename>.
        '';
      };
      installationDir = lib.mkOption {
        type = lib.types.path;
        internal = true;
        readOnly = true;
        description = "Path to installation directory.";
      };
      extraProotOptions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra options passed to proot, e.g., extra bind mounts.";
      };
    };
  };

  config = {
    build.installationDir = "/data/data/com.termux.nix/files/usr";
  };
}
