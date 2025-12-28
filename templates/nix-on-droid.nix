{
  lib,
  pkgs,
  ...
}:

{
  environment = {
    packages = with pkgs; [ helix ];
    etcBackupExtension = ".bak";
  };

  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  system.stateVersion = lib.trivial.release;
}
