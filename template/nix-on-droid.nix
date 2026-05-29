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

  users.users.nix-on-droid.shell = lib.getExe pkgs.bash;

  home-manager = {
    useGlobalPkgs = true;

    users.nix-on-droid =
      { lib, ... }:
      {
        home = {
          enableNixpkgsReleaseCheck = false;
          stateVersion = "26.05";
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
