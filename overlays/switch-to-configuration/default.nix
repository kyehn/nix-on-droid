{
  lib,
  buildGoModule,
}:

buildGoModule (finalAttrs: {
  pname = finalAttrs.meta.mainProgram;
  version = "0.1.0";
  __structuredAttrs = true;
  strictDeps = true;

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./go.sum
      ./go.mod
      ./cmd
    ];
  };

  vendorHash = "sha256-SYqxV5ulwaq1tdmzNvT4MyQCEKwNnwjdzEN2d7dVMfU=";

  subPackages = [ "cmd/${finalAttrs.meta.mainProgram}" ];

  env.CGO_ENABLED = 0;

  meta.mainProgram = "switch-to-configuration";
})
