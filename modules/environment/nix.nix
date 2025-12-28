{
  config,
  lib,
  pkgs,
  ...
}:

{
  options = {
    nix = {
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.lix;
        defaultText = lib.literalExpression "pkgs.lix";
        description = ''
          This option specifies the Nix package instance to use throughout the system.
        '';
      };
      nixPath = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          The default Nix expression search path, used by the Nix
          evaluator to look up paths enclosed in angle brackets
          (e.g. <literal>&lt;nixpkgs&gt;</literal>).
        '';
      };
      registry = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule (
            let
              referenceAttrs = lib.types.attrsOf (
                lib.types.oneOf [
                  lib.types.str
                  lib.types.int
                  lib.types.bool
                  lib.types.package
                ]
              );
            in
            { config, name, ... }:
            {
              options = {
                from = lib.mkOption {
                  type = referenceAttrs;
                  example = {
                    type = "indirect";
                    id = "nixpkgs";
                  };
                  description = "The flake reference to be rewritten.";
                };
                to = lib.mkOption {
                  type = referenceAttrs;
                  example = {
                    type = "github";
                    owner = "my-org";
                    repo = "my-nixpkgs";
                  };
                  description = "The flake reference <option>from</option> is rewritten to.";
                };
                flake = lib.mkOption {
                  type = lib.types.nullOr lib.types.attrs;
                  default = null;
                  example = lib.literalExpression "nixpkgs";
                  description = ''
                    The flake input <option>from</option> is rewritten to.
                  '';
                };
                exact = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = ''
                    Whether the <option>from</option> reference needs to match exactly. If set,
                    a <option>from</option> reference like <literal>nixpkgs</literal> does not
                    match with a reference like <literal>nixpkgs/nixos-20.03</literal>.
                  '';
                };
              };
              config = {
                from = lib.mkDefault {
                  type = "indirect";
                  id = name;
                };
                to = lib.mkIf (config.flake != null) (
                  lib.mkDefault {
                    type = "path";
                    path = config.flake.outPath;
                  }
                  // lib.filterAttrs (
                    n: _: n == "lastModified" || n == "rev" || n == "revCount" || n == "narHash"
                  ) config.flake
                );
              };
            }
          )
        );
        default = { };
        description = "A system-wide flake registry.";
      };
      substituters = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          A list of URLs of substituters.  The official NixOS and Nix-on-Droid
          substituters are added by default.
        '';
      };
      trustedPublicKeys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          A list of public keys.  When paths are copied from another Nix store (such as a
          binary cache), they must be signed with one of these keys.  The official NixOS
          and Nix-on-Droid public keys are added by default.
        '';
      };
      extraOptions = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Extra config to be appended to <filename>/etc/nix/nix.conf</filename>.";
      };
    };
  };

  config = lib.mkMerge [
    {
      environment.etc = {
        "nix/nix.conf".text = ''
          sandbox = false
          substituters = ${lib.concatStringsSep " " config.nix.substituters}
          trusted-public-keys = ${lib.concatStringsSep " " config.nix.trustedPublicKeys}
          ${config.nix.extraOptions}
        '';
        "nix/registry.json".text = builtins.toJSON {
          version = 2;
          flakes = lib.mapAttrsToList (_n: v: { inherit (v) from to exact; }) config.nix.registry;
        };
      };
      nix = {
        substituters = [
          "https://cache.nixos.org"
          "https://seilunako.cachix.org"
          "https://nix-community.cachix.org"
          "https://cache.garnix.io"
        ];
        trustedPublicKeys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "seilunako.cachix.org-1:e/aJJI1S5hPY/BPeiVZcuPjt5ZjBRRo9dlYHmvwXPFM="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="

        ];
      };
    }
    (lib.mkIf (config.nix.nixPath != [ ]) {
      environment.sessionVariables.NIX_PATH = lib.concatStringsSep ":" config.nix.nixPath;
    })
  ];
}
