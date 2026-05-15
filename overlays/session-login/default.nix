{
  config,
  lib,
  buildGoModule,
  formats,
  proot-termux,
  session-login-inner,
}:

let
  proot_binary_path = config.system.build.installationDir + "/bin/" + proot-termux.meta.mainProgram;
  login_inner_binary_path =
    config.system.build.installationDir + "/bin/" + session-login-inner.meta.mainProgram;
in
buildGoModule (finalAttrs: {
  pname = "session-login";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./go.mod
      ./go.sum
      ./cmd
    ];
  };

  vendorHash = "sha256-PPhKWy4rfVFziftRpEY8Ffs3wr0RFfcfZQToGibQuT4=";

  subPackages = [ "cmd/login" ];

  env.CGO_ENABLED = 0;

  preBuild = ''
    cp ${
      (formats.toml { }).generate "config.toml" {
        inherit login_inner_binary_path;
        installation_dir = config.system.build.installationDir;
        pending_artifacts = [
          proot_binary_path
          login_inner_binary_path
        ];
        user = {
          name = config.users.users.nix-on-droid.name;
          home = config.users.users.nix-on-droid.home;
        };
        proot = {
          bind = config.system.build.proot.bind;
          extra_args = config.system.build.proot.extraArgs;
          binary_path = proot_binary_path;
        };
      }
    } cmd/login/config.toml
  '';

  meta.mainProgram = "login";
})
