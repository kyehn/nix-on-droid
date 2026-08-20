{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.nix;
in
{
  options.nix = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to enable Nix.
        Disabling Nix makes the system hard to modify and the Nix programs and configuration will not be made available by NixOS itself.
      '';
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nix;
      defaultText = lib.literalExpression "pkgs.nix";
      description = ''
        This option specifies the Nix package instance to use throughout the system.
      '';
    };
    checkConfig = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        If enabled, checks that Nix can parse the generated nix.conf.
      '';
    };
    checkAllErrors = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        If enabled, checks the nix.conf parsing for any kind of error. When disabled, checks only for unknown settings.
      '';
    };
    extraOptions = lib.mkOption {
      type = lib.types.lines;
      default = ''
        flake-registry = ${
          pkgs.writeText "flake-registry.json" (
            builtins.toJSON {
              version = 2;
              flakes = map (name: {
                from = {
                  id = name;
                  type = "indirect";
                };
                to = {
                  type = "path";
                  path = inputs.${name};
                };
              }) (builtins.filter (name: name != "self") (builtins.attrNames inputs));
            }
          )
        }
        nix-path = nixpkgs=${inputs.nixpkgs}
      '';
      example = ''
        keep-outputs = true
        keep-derivations = true
      '';
      description = "Additional text appended to {file}`nix.conf`.";
    };
    settings = lib.mkOption {
      type = lib.types.submodule {
        options = {
          substituters = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            example = [ "https://cache.nixos.org/" ];
            description = ''
              List of binary cache URLs used to obtain pre-built binaries
              of Nix packages.

              By default https://cache.nixos.org/ is added.
            '';
          };
          trusted-substituters = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            example = [ "https://hydra.nixos.org/" ];
            description = ''
              List of binary cache URLs that non-root users can use (in
              addition to those specified using
              {option}`nix.settings.substituters`) by passing
              `--option binary-caches` to Nix commands.
            '';
          };
          require-sigs = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              If enabled (the default), Nix will only download binaries from binary caches if
              they are cryptographically signed with any of the keys listed in
              {option}`nix.settings.trusted-public-keys`. If disabled, signatures are neither
              required nor checked, so it's strongly recommended that you use only
              trustworthy caches and https to prevent man-in-the-middle attacks.
            '';
          };
          trusted-public-keys = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            example = [ "hydra.nixos.org-1:CNHJZBh9K4tP3EKF6FkkgeVYsS3ohTl+oS0Qa8bezVs=" ];
            description = ''
              List of public keys used to sign binary caches. If
              {option}`nix.settings.trusted-public-keys` is enabled,
              then Nix will use a binary from a binary cache if and only
              if it is signed by *any* of the keys
              listed here. By default, only the key for
              `cache.nixos.org` is included.
            '';
          };
          experimental-features = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            example = [
              "nix-command"
              "flakes"
            ];
            description = ''
              Experimental features to enable in Nix.
            '';
          };
          max-jobs = lib.mkOption {
            type = lib.types.either lib.types.int (lib.types.enum [ "auto" ]);
            default = 1;
            example = 64;
            description = ''
              This option defines the maximum number of jobs that Nix will try to
              build in parallel. The default is auto, which means it will use all
              available logical cores. It is recommend to set it to the total
              number of logical cores in your system (e.g., 16 for two CPUs with 4
              cores each and hyper-threading).
            '';
          };
          cores = lib.mkOption {
            type = lib.types.int;
            default = 1;
            example = 64;
            description = ''
              This option defines the maximum number of concurrent tasks during
              one build. It affects, e.g., -j option for make.
              The special value 0 means that the builder should use all
              available CPU cores in the system. Some builds may become
              non-deterministic with this option; use with care! Packages will
              only be affected if enableParallelBuilding is set for them.
            '';
          };
          system-features = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            defaultText = lib.literalExpression "[ ]";
            description = ''
              The set of features supported by the machine. Derivations
              can express dependencies on system features through the
              `requiredSystemFeatures` attribute.
            '';
          };
        };
      };
      default = { };
      description = ''
        Configuration for Nix, see
        <link linkend="chap-conf-files">
        Nix configuration</link> for available options.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    nix.settings = {
      substituters = lib.mkAfter [
        "https://cache.nixos.org"
        "https://seilunako.cachix.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "seilunako.cachix.org-1:e/aJJI1S5hPY/BPeiVZcuPjt5ZjBRRo9dlYHmvwXPFM="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
    environment.etc."nix/nix.conf".source =
      (pkgs.formats.nixConf {
        inherit (cfg)
          package
          checkAllErrors
          checkConfig
          extraOptions
          ;
        inherit (cfg.package) version;
      }).generate
        "nix.conf"
        (
          cfg.settings
          // {
            sandbox = false;
            allow-unsafe-native-code-during-evaluation = true;
            trusted-users = [ ];
          }
        );
  };
}
