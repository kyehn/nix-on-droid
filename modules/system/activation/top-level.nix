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
          install -D --mode=0755 ${
            lib.getExe (pkgs.switch-to-configuration.override { inherit config; })
          } bin/switch-to-configuration
        '';
      });
}
