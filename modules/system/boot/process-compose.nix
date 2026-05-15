{
  lib,
  pkgs,
  options,
  config,
  ...
}:

let
  stripEmptyAttrs =
    value:
    if lib.isAttrs value then
      let
        isDerivation = v: lib.isAttrs v && v ? type && v.type == "derivation";

        cleaned = lib.mapAttrs (
          _: v: if lib.isAttrs v && !isDerivation v then stripEmptyAttrs v else v
        ) value;

        nonEmpty = lib.filterAttrs (_: v: !(v == null || (lib.isAttrs v && v == { }))) cleaned;
      in
      nonEmpty
    else
      value;

  generateProcessComposeConfigFile =
    processComposeConfig:
    (pkgs.formats.yaml { }).generate "process-compose.yaml" (
      stripEmptyAttrs (if processComposeConfig == null then { } else processComposeConfig)
    );
in
{
  options.programs = {
    process-compose = {
      config = lib.mkOption {
        type = lib.types.submodule {
          freeformType = lib.types.attrsOf lib.types.anything;
          options = {
            version = lib.mkOption {
              type = lib.types.str;
              default = "0.5";
            };

            shell = lib.mkOption {
              default = { };
              type = lib.types.submodule {
                freeformType = lib.types.attrsOf lib.types.anything;
                options = {
                  shell_command = lib.mkOption {
                    type = lib.types.str;
                    default = lib.getExe pkgs.bashNonInteractive;
                  };
                  shell_argument = lib.mkOption {
                    type = lib.types.str;
                    default = "-c";
                  };
                };
              };
            };

            log_configuration = lib.mkOption {
              default = { };
              type = lib.types.submodule {
                freeformType = lib.types.attrsOf lib.types.anything;
                options = {
                  rotation = lib.mkOption {
                    default = { };
                    type = lib.types.attrsOf (
                      lib.types.submodule {
                        freeformType = lib.types.attrsOf lib.types.anything;
                        options = {
                          compress = lib.mkOption {
                            type = lib.types.bool;
                            default = false;
                          };
                        };
                      }
                    );
                  };
                };
              };
            };

            processes = lib.mkOption {
              default = { };
              type = lib.types.attrsOf (
                lib.types.submodule {
                  freeformType = lib.types.attrsOf lib.types.anything;
                  options = {
                    command = lib.mkOption {
                      type = lib.types.str;
                    };

                    depends_on = lib.mkOption {
                      default = { };
                      type = lib.types.attrsOf (
                        lib.types.submodule {
                          freeformType = lib.types.attrsOf lib.types.anything;
                          options = {
                            condition = lib.mkOption {
                              type = lib.types.enum [
                                "process_started"
                                "process_healthy"
                                "process_completed"
                                "process_completed_successfully"
                                "process_log_ready"
                              ];
                              default = "process_completed_successfully";
                            };
                          };
                        }
                      );
                    };

                    availability = lib.mkOption {
                      default = { };
                      type = lib.types.submodule {
                        freeformType = lib.types.attrsOf lib.types.anything;
                        options = {
                          restart = lib.mkOption {
                            type = lib.types.enum [
                              "always"
                              "on_failure"
                              "exit_on_failure"
                              "no"
                            ];
                            default = "no";
                          };
                        };
                      };
                    };
                  };
                }
              );
            };
          };
        };
        default = { };
      };

      configFile = lib.mkOption {
        type = lib.types.path;
        default = generateProcessComposeConfigFile config.programs.process-compose.config;
      };
    };
    switch-to-configuration.process-compose = {
      config = lib.mkOption {
        type = options.programs.process-compose.config.type;
        default = { };
      };
      configFile = lib.mkOption {
        type = lib.types.path;
        default = generateProcessComposeConfigFile config.programs.switch-to-configuration.process-compose.config;
      };
    };
  };
}
