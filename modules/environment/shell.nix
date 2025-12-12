{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{

  ###### interface

  options = { };

  ###### implementation

  config = {

    environment.etc = {
      "profile".text = ''
        . "${config.build.sessionInit}/etc/profile.d/nix-on-droid-session-init.sh"
      '';

      "zshenv".text = ''
        . "${config.build.sessionInit}/etc/profile.d/nix-on-droid-session-init.sh"
      '';
    };

  };

}
