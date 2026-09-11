{
  lib,
  pkgs,
  ...
}:

{
  environment = {
    systemPackages = with pkgs; [ helix ];
    sessionVariables.EDITOR = "hx";
  };

  users.users.root.shell = lib.getExe pkgs.bash;

  home-manager = {
    useGlobalPkgs = true;

    users.root =
      { lib, ... }:
      {
        home = {
          enableNixpkgsReleaseCheck = false;
          stateVersion = lib.trivial.release;
        };
        systemd.user.enable = false;
        programs.man = {
          enable = false;
          generateCaches = false;
        };
        manual = {
          html.enable = false;
          json.enable = false;
          manpages.enable = false;
        };
      };
  };
}
