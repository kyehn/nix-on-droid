{
  inputs,
  configuration,
  pkgs,
  lib ? pkgs.lib,
  extraSpecialArgs ? { },
}:

let
  specialArgs = lib.recursiveUpdate {
    inherit inputs lib pkgs;
  } extraSpecialArgs;

  evaluated = lib.evalModules {
    class = "nixos";
    modules = [ configuration ] ++ import ./modules.nix { inherit lib pkgs; };
    inherit specialArgs;
  };

  failedAssertions = lib.filter (assertion: !assertion.assertion) evaluated.config.assertions;

  baseConfiguration = {
    _type = "configuration";
    inherit lib pkgs specialArgs;
    inherit (evaluated) _module config options;
    modules = evaluated._module.args.modules or [ ];
    extendModules =
      modules:
      import ./default.nix {
        inherit
          extraSpecialArgs
          inputs
          lib
          pkgs
          ;
        configuration = {
          imports = [ configuration ] ++ modules;
        };
      };
  };
in
if failedAssertions != [ ] then
  throw "\nFailed assertions:\n${
    lib.concatMapStringsSep "\n" (assertion: "- ${assertion.message}") failedAssertions
  }"
else
  lib.showWarnings evaluated.config.warnings baseConfiguration
