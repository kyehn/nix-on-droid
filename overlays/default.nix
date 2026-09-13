{ inputs, ... }:

final: prev:
let
  inherit (prev) lib;

  modules = import ../modules {
    inherit inputs;
    pkgs = prev.extend (
      _: _: {
        inherit (final) proot-termux;
      }
    );

    configuration.config.system.build.bootstrapBuild = true;
  };
in
{
  bootstrapClosureInfo = prev.closureInfo {
    rootPaths = [ modules.config.system.build.toplevel ];
  };
  session-login = prev.callPackage ./session-login { inherit (modules) config; };
  session-login-inner = prev.callPackage ./session-login-inner {
    inherit (modules) config;
  };
  switch-to-configuration = prev.callPackage ./switch-to-configuration { inherit (modules) config; };
  proot-termux = prev.pkgsStatic.pkgsLLVM.callPackage ./proot-termux {
    talloc = prev.pkgsStatic.pkgsLLVM.callPackage ./talloc.nix { };
    stdenv = prev.pkgsStatic.pkgsLLVM.stdenvAdapters.makeStaticBinaries prev.pkgsStatic.pkgsLLVM.stdenv;
  };
  smfh = prev.smfh.overrideAttrs (oldAttrs: {
    postPatch = (oldAttrs.postPatch or "") + ''
      substituteInPlace crates/smfh-core/src/file_util.rs \
        --replace-fail "if self.uid.is_some() || self.gid.is_some() {" "if false && (self.uid.is_some() || self.gid.is_some()) {" \
        --replace-fail "fs::symlink_metadata(source).is_ok_and" "fs::metadata(source).is_ok_and"
    '';
  });
  process-compose = prev.process-compose.overrideAttrs (oldAttrs: {
    postPatch = (oldAttrs.postPatch or "") + ''
      substituteInPlace src/config/config.go \
        --replace-fail "xdg.SearchConfigFile(configHome)" "xdg.ConfigFile(configHome)" \
        --replace-fail 'log.Debug().Err(err).Msg("Path not found for process compose config home")' 'if err == nil && xdgPcHome == "" { return "" }'
    '';
  });
  bootstrap = prev.callPackage ./bootstrap.nix {
    inherit (modules) config;
  };
  bootstrap-zip = prev.callPackage ./bootstrap-zip.nix { };
}
