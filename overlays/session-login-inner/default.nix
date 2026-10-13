{
  config,
  lib,
  buildGoModule,
}:

buildGoModule (finalAttrs: {
  pname = "session-${finalAttrs.meta.mainProgram}";
  version = "0.1.0";
  __structuredAttrs = true;
  strictDeps = true;

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./go.mod
      ./go.sum
      ./cmd
    ];
  };

  vendorHash = "sha256-/Ox7fGsUo1dORSqxuuFTbKb89Y/ZjTlEwpBLqcAVfDk=";

  subPackages = [ "cmd/${finalAttrs.meta.mainProgram}" ];

  env.CGO_ENABLED = 0;

  postPatch = ''
    substituteInPlace ./cmd/${finalAttrs.meta.mainProgram}/main.go \
      --replace-fail "@config_file@" "${config.system.build.installationDir}/etc/${finalAttrs.meta.mainProgram}.toml"
  '';

  meta.mainProgram = "login-inner";
})
