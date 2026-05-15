{
  config,
  lib,
  ...
}:

let
  cfg = config.networking;
in
{
  options.networking = {
    nameservers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "223.6.6.6"
        "8.8.8.8"
      ];
      example = [
        "130.161.158.4"
        "130.161.33.17"
      ];
      description = "The list of nameservers.";
    };
    hostName = lib.mkOption {
      default = "nixos";
      # Only allow hostnames without the domain name part (i.e. no FQDNs, see
      # e.g. "man 5 hostname") and require valid DNS labels (recommended
      # syntax). Note: We also allow underscores for compatibility/legacy
      # reasons (as undocumented feature):
      type = lib.types.strMatching "^$|^[[:alnum:]]([[:alnum:]_-]{0,61}[[:alnum:]])?$";
      description = ''
        The name of the machine. Leave it empty if you want to obtain it from a
        DHCP server (if using DHCP). The hostname must be a valid DNS label (see
        RFC 1035 section 2.3.1: "Preferred name syntax", RFC 1123 section 2.1:
        "Host Names and Numbers") and as such must not contain the domain part.
        This means that the hostname must start with a letter or digit,
        end with a letter or digit, and have as interior characters only
        letters, digits, and hyphen. The maximum length is 63 characters.
        Additionally it is recommended to only use lower-case characters.
        If (e.g. for legacy reasons) a FQDN is required as the Linux kernel
        network node hostname (uname --nodename) the option
        boot.kernel.sysctl."kernel.hostname" can be used as a workaround (but
        the 64 character limit still applies).

        WARNING: Do not use underscores (_) or you may run into unexpected issues.
      '';
      # warning until the issues in https://github.com/NixOS/nixpkgs/pull/138978
      # are resolved
    };
    domain = lib.mkOption {
      default = null;
      example = "home.arpa";
      type = lib.types.nullOr lib.types.str;
      description = ''
        The system domain name. Used to populate the {option}`fqdn` value.

        ::: {.warning}
        The domain name is not configured for DNS resolution purposes, see {option}`search` instead.
        :::
      '';
    };
    enableIPv6 = lib.mkOption {
      default = true;
      type = lib.types.bool;
      description = ''
        Whether to enable support for IPv6.
      '';
    };
  };

  config.environment.etc = {
    "resolv.conf".text = lib.concatMapStrings (
      nameserver: "nameserver ${nameserver}\n"
    ) config.networking.nameservers;
    # static hostname configuration needed for hostnamectl and the
    # org.freedesktop.hostname1 dbus service (both provided by systemd)
    hostname = lib.mkIf (cfg.hostName != "") {
      text = cfg.hostName + "\n";
    };
  };
}
