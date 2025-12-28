{
  config,
  lib,
  ...
}:

{
  config = {
    _module.args.pkgs = import <nixpkgs> (lib.filterAttrs (_n: v: v != null) config.nixpkgs);
    nixpkgs.overlays = import ../../overlays;
  };
}
