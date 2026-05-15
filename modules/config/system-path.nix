{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.environment;
in
{
  options = {
    environment = {
      systemPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        example = lib.literalExpression "[ pkgs.helix pkgs.neovim ]";
        description = "The set of packages to appear in the nix-on-droid environment.";
      };
      pathsToLink = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "/" ];
        description = "List of directories to be symlinked in the user environment.";
      };
      extraOutputsToInstall = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [
          "dev"
          "info"
        ];
        description = ''
          Extra derivation outputs to install.
          Entries listed here will be appended to the `meta.outputsToInstall` attribute
          for each package in `environment.packages`, and the files from the
          corresponding derivation outputs will be symlinked into the user environment.
        '';
      };
      extraSetup = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = ''
          Shell fragments to be run after the user environment has been created.
          This should only be used for things that need to modify the internals
          of the environment, e.g. generating caches. The environment being built
          can be accessed at $out.
        '';
      };
    };
    system.path = lib.mkOption {
      type = lib.types.package;
      internal = true;
      description = "Derivation for installing user packages.";
    };
  };

  config = {
    environment = {
      systemPackages = with pkgs; [
        config.nix.package
        curl
        diffutils
        gawk
        gnugrep
        gnupatch
        gnused
        util-linux
        gzip
        less
        coreutils
        findutils
        procps
        ncurses
        netcat-openbsd
        openssh
        time
        which
        nixos-rebuild-ng
        process-compose
      ];
      pathsToLink = [
        "/bin"
        "/sbin"
        "/etc/profile.d"
      ];
    };

    system.path = pkgs.buildEnv {
      name = "system-path";
      paths = cfg.systemPackages;
      inherit (cfg) pathsToLink extraOutputsToInstall;
      ignoreCollisions = true;
      # Remove wrapped binaries, they shouldn't be accessible via PATH.
      postBuild = ''
        find $out/bin -maxdepth 1 -name ".*-wrapped" -type l -delete
        find $out/sbin -maxdepth 1 -name ".*-wrapped" -type l -delete
        find $out/bin -maxdepth 1 -name ".*-wrapped_*" -type l -delete
        find $out/sbin -maxdepth 1 -name ".*-wrapped_*" -type l -delete
        if [ -x $out/bin/glib-compile-schemas -a -w $out/share/glib-2.0/schemas ]; then
          $out/bin/glib-compile-schemas $out/share/glib-2.0/schemas
        fi
        ${lib.optionalString (
          !(lib.attrByPath [ "nix" "channel" "enable" ] false config)
        ) "rm --force $out/bin/nix-channel"}
        ${cfg.extraSetup}
      '';
    };
  };
}
