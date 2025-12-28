{
  config,
  lib,
  pkgs,
  ...
}:

let
  validColorname =
    colorName:
    lib.elem colorName [
      "background"
      "foreground"
      "cursor"
    ]
    ++ (map (n: "color${toString n}") (lib.lists.range 0 15));
in
{
  options = {
    terminal = {
      font = lib.mkOption {
        default = null;
        type = lib.types.nullOr lib.types.path;
        example = lib.literalExpression "'${pkgs.terminus_font_ttf}/share/fonts/truetype/TerminusTTF.ttf";
        description = ''
          Font used for the terminal.
        '';
      };
      colors = lib.mkOption {
        default = { };
        type = lib.types.lazyAttrsOf lib.types.str;
        example = lib.literalExpression ''
          {
            background = "#000000";
            foreground = "#FFFFFF";
            cursor = "#FFFFFF";
          }
        '';
        description = ''
          Colorscheme used for the terminal.
          Acceptable attribute names are:
          `background`, `foreground`, `cursor` and `color0`-`color15`.
        '';
      };
    };
  };

  config = {
    assertions = [
      {
        assertion = lib.all validColorname (lib.attrNames config.terminal.colors);
        message = ''
          `terminal.colors` only accepts the following attributes:
          `background`, `foreground`, `cursor` and `color0`-`color15`.
        '';
      }
    ];
    build.activation =
      let
        fontPath =
          if (lib.strings.hasPrefix "/nix" config.terminal.font) then
            "${config.build.installationDir}/${config.terminal.font}"
          else
            config.terminal.font;
        configDir = "${config.user.home}/.termux";
        fontTarget = "${configDir}/font.ttf";
        fontBackup = "${configDir}/font.ttf.bak";
        colors = pkgs.writeTextFile {
          name = "colors.properties";
          text = lib.generators.toKeyValue { } config.terminal.colors;
        };
        colorsTarget = "${configDir}/colors.properties";
        colorsBackup = "${configDir}/colors.properties.bak";
        colorsPath = "${config.build.installationDir}/${colors}";
      in
      (
        if (config.terminal.font != null) then
          {
            linkFont = ''
              $DRY_RUN_CMD mkdir $VERBOSE_ARG -p "${configDir}"
              if [ -e "${fontTarget}" ] && ! [ -L "${fontTarget}" ]; then
                $DRY_RUN_CMD mv $VERBOSE_ARG "${fontTarget}" "${fontBackup}"
                $DRY_RUN_CMD echo "${fontTarget} has been moved to ${fontBackup}"
              fi
              $DRY_RUN_CMD ln $VERBOSE_ARG -sf "${fontPath}" "${fontTarget}"
            '';
          }
        else
          {
            unlinkFont = ''
              if [ -e "${fontTarget}" ] && [ -L "${fontTarget}" ]; then
                $DRY_RUN_CMD rm $VERBOSE_ARG "${fontTarget}"
                if [ -e "${fontBackup}" ]; then
                  $DRY_RUN_CMD mv $VERBOSE_ARG "${fontBackup}" "${fontTarget}"
                  $DRY_RUN_CMD echo "${fontTarget} has been restored from backup"
                else
                  if $DRY_RUN_CMD rm $VERBOSE_ARG -d "${configDir}" 2>/dev/null
                  then
                    $DRY_RUN_CMD echo "removed empty ${configDir}"
                  fi
                fi
              fi
            '';
          }
      )
      // (
        if (config.terminal.colors != { }) then
          {
            linkColors = ''
              $DRY_RUN_CMD mkdir $VERBOSE_ARG -p "${configDir}"
              if [ -e "${colorsTarget}" ] && ! [ -L "${colorsTarget}" ]; then
                $DRY_RUN_CMD mv $VERBOSE_ARG "${colorsTarget}" "${colorsBackup}"
                $DRY_RUN_CMD echo "${colorsTarget} has been moved to ${colorsBackup}"
              fi
              $DRY_RUN_CMD ln $VERBOSE_ARG -sf "${colorsPath}" "${colorsTarget}"
            '';
          }
        else
          {
            unlinkColors = ''
              if [ -e "${colorsTarget}" ] && [ -L "${colorsTarget}" ]; then
                $DRY_RUN_CMD rm $VERBOSE_ARG "${colorsTarget}"
                if [ -e "${colorsBackup}" ]; then
                  $DRY_RUN_CMD mv $VERBOSE_ARG "${colorsBackup}" "${colorsTarget}"
                  $DRY_RUN_CMD echo "${colorsTarget} has been restored from backup"
                else
                  if $DRY_RUN_CMD rm $VERBOSE_ARG -d "${configDir}" 2>/dev/null
                  then
                    $DRY_RUN_CMD echo "removed empty ${configDir}"
                  fi
                fi
              fi
            '';
          }
      );
  };
}
