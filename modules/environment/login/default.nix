{
  config,
  lib,
  pkgs,
  initialPackageInfo,
  ...
}:

let
  login = pkgs.callPackage ./login.nix { inherit config; };
  loginInner = pkgs.callPackage ./login-inner.nix {
    inherit config initialPackageInfo;
  };
in
{
  options = {
    environment.files = {
      login = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        internal = true;
        description = "Login script.";
      };
      loginInner = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        internal = true;
        description = "Login-inner script.";
      };
      prootStatic = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        internal = true;
        description = "<literal>proot-static</literal> package.";
      };
    };
  };

  config = {
    build.activation = {
      installLogin = ''
        if ! diff /bin/login ${login} > /dev/null; then
          $DRY_RUN_CMD mkdir $VERBOSE_ARG --parents /bin
          $DRY_RUN_CMD cp $VERBOSE_ARG ${login} /bin/.login.tmp
          $DRY_RUN_CMD chmod $VERBOSE_ARG u+w /bin/.login.tmp
          $DRY_RUN_CMD mv $VERBOSE_ARG /bin/.login.tmp /bin/login
        fi
      '';
      installLoginInner = ''
        if (test -e /usr/lib/.login-inner.new && ! diff /usr/lib/.login-inner.new ${loginInner} > /dev/null) || \
            (! test -e /usr/lib/.login-inner.new && ! diff /usr/lib/login-inner ${loginInner} > /dev/null); then
          $DRY_RUN_CMD mkdir $VERBOSE_ARG --parents /usr/lib
          $DRY_RUN_CMD cp $VERBOSE_ARG ${loginInner} /usr/lib/.login-inner.tmp
          $DRY_RUN_CMD chmod $VERBOSE_ARG u+w /usr/lib/.login-inner.tmp
          $DRY_RUN_CMD mv $VERBOSE_ARG /usr/lib/.login-inner.tmp /usr/lib/.login-inner.new
        fi
      '';
      installProotStatic = ''
        if (test -e /bin/.proot-static.new && ! diff /bin/.proot-static.new ${config.environment.files.prootStatic}/bin/proot-static > /dev/null) || \
            (! test -e /bin/.proot-static.new && ! diff /bin/proot-static ${config.environment.files.prootStatic}/bin/proot-static > /dev/null); then
          $DRY_RUN_CMD mkdir $VERBOSE_ARG --parents /bin
          $DRY_RUN_CMD cp $VERBOSE_ARG ${config.environment.files.prootStatic}/bin/proot-static /bin/.proot-static.tmp
          $DRY_RUN_CMD chmod $VERBOSE_ARG u+w /bin/.proot-static.tmp
          $DRY_RUN_CMD mv $VERBOSE_ARG /bin/.proot-static.tmp /bin/.proot-static.new
        fi
      '';
    };
    environment.files = {
      inherit login loginInner;
      prootStatic = "/nix/store/15ic9vpd1r4z108v2lz0gqc3p68hx75w-proot-termux-static-aarch64-unknown-linux-android-0-unstable-2025-10-19";
    };
  };
}
