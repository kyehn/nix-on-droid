{ inputs, ... }:

final: prev:
let
  inherit (prev) lib;

  modules = import ../modules {
    inherit inputs;
    pkgs = prev.extend (
      _: _: {
        inherit (final) login switch-to-configuration;
      }
    );

    configuration.config.system.build.userlandBuild = true;
  };
in
{
  userlandClosureInfo = prev.closureInfo {
    rootPaths = [ modules.config.system.build.toplevel ];
  };
  login = prev.callPackage ./login {
    inherit (modules) config;
  };
  switch-to-configuration = prev.callPackage ./switch-to-configuration { inherit (modules) config; };
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
  userland = prev.callPackage ./userland.nix {
    inherit (modules) config;
  };
  userland-archive = prev.callPackage ./userland-archive.nix { };
}
