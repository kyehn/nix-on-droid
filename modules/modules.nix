{
  lib,
  pkgs,
}:

[
  ./config/users-groups.nix
  ./config/environment.nix
  ./config/system-path.nix
  ./config/nix.nix
  ./config/ldso.nix
  ./security/ca.nix
  ./system/build.nix
  ./system/files.nix
  ./system/activation/top-level.nix
  ./system/boot/process-compose.nix
  ./tasks/network-interfaces.nix
  (builtins.toFile "i18n.nix" (
    lib.replaceStrings
      [
        ''
          ${"    "}systemd.globalEnvironment = lib.mkIf (config.i18n.supportedLocales != [ ]) {
          ${"      "}LOCALE_ARCHIVE = "''${config.i18n.glibcLocales}/lib/locale/locale-archive";
          ${"    "}};
        ''
        ''LOCALE_ARCHIVE = "/run/current-system/sw/lib/locale/locale-archive";''
      ]
      [ "" ''LOCALE_ARCHIVE = "''${config.i18n.glibcLocales}/lib/locale/locale-archive";'' ]
      (builtins.readFile (pkgs.path + "/nixos/modules/config/i18n.nix"))
  ))
  (builtins.toFile "locale.nix" (
    lib.replaceStrings
      [
        ''services.geoclue2.enable = lib.mkIf (lcfg.provider == "geoclue2") true;''
        "systemd.globalEnvironment.TZDIR = tzdir;"
        ''
          ${"    "}systemd.services.systemd-timedated.environment = lib.optionalAttrs (config.time.timeZone != null) {
          ${"      "}NIXOS_STATIC_TIMEZONE = "1";
          ${"    "}};
        ''
      ]
      [ "" "" "" ]
      (builtins.readFile (pkgs.path + "/nixos/modules/config/locale.nix"))
  ))
  (builtins.toFile "environment.nix" (
    lib.replaceStrings
      [
        ''EDITOR = lib.mkDefault "nano";''
        ''
          ${"      "}INFOPATH = [
          ${"        "}"/info"
          ${"        "}"/share/info"
          ${"      "}];
          ${"      "}QTWEBKIT_PLUGIN_PATH = [ "/lib/mozilla/plugins/" ];
          ${"      "}GTK_PATH = [
          ${"        "}"/lib/gtk-2.0"
          ${"        "}"/lib/gtk-3.0"
          ${"        "}"/lib/gtk-4.0"
          ${"      "}];
        ''
        ''
          ${"    "}environment.pathsToLink = [
          ${"      "}"/lib/gtk-2.0"
          ${"      "}"/lib/gtk-3.0"
          ${"      "}"/lib/gtk-4.0"
          ${"    "}];
        ''
      ]
      [ ''EDITOR = lib.mkDefault "hx";'' "" "" ]
      (builtins.readFile (pkgs.path + "/nixos/modules/programs/environment.nix"))
  ))
  (builtins.toFile "nix-ld.nix" (
    lib.replaceStrings
      [
        ''
          ${"    "}programs.nix-ld.libraries = with pkgs; [
          ${"      "}zlib
          ${"      "}zstd
          ${"      "}stdenv.cc.cc
          ${"      "}curl
          ${"      "}openssl
          ${"      "}attr
          ${"      "}libssh
          ${"      "}bzip2
          ${"      "}libxml2
          ${"      "}acl
          ${"      "}libsodium
          ${"      "}util-linux
          ${"      "}xz
          ${"      "}systemd
          ${"    "}];
        ''
      ]
      [
        ''
          programs.nix-ld.libraries = with pkgs; [
            bzip2
            curl
            libsodium
            libssh
            libxml2
            openssl
            stdenv.cc.cc
            util-linux
            xz
            (zlib-ng.override {
              withZlibCompat = true;
            })
            zstd
          ];
        ''
      ]
      (builtins.readFile (pkgs.path + "/nixos/modules/programs/nix-ld.nix"))
  ))
  (builtins.toFile "label.nix" (
    lib.replaceStrings [ "cfg.version" ] [ ''"${lib.trivial.release}.1160.f2d4ee1"'' ] (
      builtins.readFile (pkgs.path + "/nixos/modules/misc/label.nix")
    )
  ))
  (pkgs.path + "/nixos/modules/config/networking.nix")
  (pkgs.path + "/nixos/modules/misc/assertions.nix")
  (pkgs.path + "/nixos/modules/programs/less.nix")
  (pkgs.path + "/modules/generic/meta-maintainers.nix")
  (pkgs.path + "/nixos/modules/misc/ids.nix")
  (pkgs.path + "/nixos/modules/config/nsswitch.nix")
  (pkgs.path + "/nixos/modules/config/xdg/icons.nix")
  (pkgs.path + "/nixos/modules/config/xdg/mime.nix")
  (pkgs.path + "/nixos/modules/config/xdg/terminal-exec.nix")
  (pkgs.path + "/nixos/modules/config/appstream.nix")
  (pkgs.path + "/nixos/modules/config/debug-info.nix")
  (pkgs.path + "/nixos/modules/config/getaddrinfo.nix")
  (pkgs.path + "/nixos/modules/config/iproute2.nix")
  (pkgs.path + "/nixos/modules/config/nix-flakes.nix")
  (pkgs.path + "/nixos/modules/config/unix-odbc-drivers.nix")
]
