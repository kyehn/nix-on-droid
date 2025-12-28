{
  config ? null,
  extraSpecialArgs ? { },
  pkgs ? import <nixpkgs> { },
  home-manager-path ? <home-manager>,
  isFlake ? false,
}:

let
  defaultConfigFile = "${builtins.getEnv "HOME"}/.config/nixpkgs/nix-on-droid.nix";

  configModule =
    if config != null then
      config
    else if builtins.pathExists defaultConfigFile then
      defaultConfigFile
    else
      pkgs.config.nix-on-droid
        or (throw "No config file found! Create one in ~/.config/nixpkgs/nix-on-droid.nix");

  nodModules = import ./module-list.nix {
    inherit pkgs home-manager-path isFlake;
  };

  rawModule = pkgs.lib.evalModules {
    modules = [ configModule ] ++ nodModules;
    specialArgs = extraSpecialArgs;
    class = "nixOnDroid";
  };

  failedAssertions = map (x: x.message) (
    pkgs.lib.filter (x: !x.assertion) rawModule.config.assertions
  );

  module =
    if failedAssertions != [ ] then
      throw "\nFailed assertions:\n${pkgs.lib.concatMapStringsSep "\n" (x: "- ${x}") failedAssertions}"
    else
      pkgs.lib.showWarnings rawModule.config.warnings rawModule;
in

{
  inherit (module.config.build) activationPackage;
  inherit (module) config options;
  inherit pkgs;
}
