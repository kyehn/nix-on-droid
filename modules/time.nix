{
  config,
  lib,
  pkgs,
  ...
}:
let
  nospace = str: lib.filter (c: c == " ") (lib.stringToCharacters str) == [ ];
  timezoneType = lib.types.nullOr (lib.types.addCheck lib.types.str nospace) // {
    description = "null or string without spaces";
  };
in
{
  options = {
    time.timeZone = lib.mkOption {
      default = null;
      type = timezoneType;
      example = "America/New_York";
      description = ''
        The time zone used when displaying times and dates. See <link
        xlink:href="https://en.wikipedia.org/wiki/List_of_tz_database_time_zones"/>
        for a comprehensive list of possible values for this setting.
        If null, the timezone will default to UTC.
      '';
    };
  };

  config = {
    environment = {
      etc = {
        zoneinfo.source = "${pkgs.tzdata}/share/zoneinfo";
      }
      // lib.optionalAttrs (config.time.timeZone != null) {
        localtime.source = "/etc/zoneinfo/${config.time.timeZone}";
      };
      sessionVariables.TZDIR = "/etc/zoneinfo";
    };
  };
}
