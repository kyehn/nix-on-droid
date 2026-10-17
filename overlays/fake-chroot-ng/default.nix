{
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "fake-chroot-ng";
  version = "1.1.0-unstable-2026-10-14";

  src = fetchFromGitHub {
    owner = "sylirre";
    repo = "fake-chroot-ng";
    rev = "12d07c1a4da8d4c159899633fbfab3bd8ceeeee8";
    hash = "sha256-J22RQ5/TEttI+HOnshiIMNH51kN5jNOh2hC1YX+iW68=";
  };

  patches = [ ./fix-unfollowed-magic-links.patch ];

  CFLAGS = [
    "-O2"
    "-Werror"
  ];

  installPhase = ''
    runHook preInstall

    install -D --mode=0755 build/${finalAttrs.meta.mainProgram} $out/bin/${finalAttrs.meta.mainProgram}
    ${stdenv.cc.targetPrefix}strip --strip-unneeded $out/bin/${finalAttrs.meta.mainProgram}

    runHook postInstall
  '';

  meta = {
    mainProgram = "chroot-ng";
    platforms = [ "aarch64-linux" ];
  };
})
