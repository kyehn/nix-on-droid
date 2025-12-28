{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.networking = {
    hosts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      example = lib.literalExpression ''
        {
          "127.0.0.1" = [ "foo.bar.baz" ];
          "192.168.0.2" = [ "fileserver.local" "nameserver.local" ];
        };
      '';
      description = lib.mdDoc ''
        Locally defined maps of hostnames to IP addresses.
      '';
    };
    hostFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      defaultText = lib.literalMD "Hosts from {option}`networking.hosts` and {option}`networking.extraHosts`";
      example = lib.literalExpression ''[ "''${pkgs.my-blocklist-package}/share/my-blocklist/hosts" ]'';
      description = lib.mdDoc ''
        Files that should be concatenated together to form {file}`/etc/hosts`.
      '';
    };
    extraHosts = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = "192.168.0.1 lanlocalhost";
      description = lib.mdDoc ''
        Additional verbatim entries to be appended to {file}`/etc/hosts`.
        For adding hosts from derivation results, use {option}`networking.hostFiles` instead.
      '';
    };
  };

  config = {
    assertions = [
      {
        assertion =
          !(lib.any (lib.elem "localhost") (
            lib.attrValues (
              lib.removeAttrs config.networking.hosts [
                "127.0.0.1"
                "::1"
              ]
            )
          ));
        message = ''
          `networking.hosts` maps "localhost" to something other than "127.0.0.1"
          or "::1". This will break some applications. Please use
          `networking.extraHosts` if you really want to add such a mapping.
        '';
      }
    ];
    networking.hostFiles =
      let
        stringHosts =
          let
            oneToString = set: ip: ip + " " + lib.concatStringsSep " " set.${ip} + "\n";
            allToString = set: lib.concatMapStrings (oneToString set) (lib.attrNames set);
          in
          pkgs.writeText "string-hosts" (
            allToString (lib.filterAttrs (_: v: v != [ ]) config.networking.hosts)
          );
        extraHosts = pkgs.writeText "extra-hosts" config.networking.extraHosts;
      in
      lib.mkBefore [
        (pkgs.writeText "localhost-hosts" ''
          127.0.0.1 localhost
          ::1 localhost
        '')
        stringHosts
        extraHosts
      ];
    environment.etc = {
      # /etc/services: TCP/UDP port assignments.
      services.source = pkgs.iana-etc + "/etc/services";
      # /etc/protocols: IP protocol numbers.
      protocols.source = pkgs.iana-etc + "/etc/protocols";
      # /etc/hosts: Hostname-to-IP mappings.
      hosts.source = pkgs.concatText "hosts" config.networking.hostFiles;
      "resolv.conf".text = ''
        nameserver 1.1.1.1
        nameserver 8.8.8.8
      '';
    };
  };
}
