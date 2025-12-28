{
  lib,
  ...
}:

{
  options = {
    system.stateVersion = lib.mkOption {
      type = lib.types.enum [ lib.trivial.release ];
      default = lib.trivial.release;
    };
  };
}
