{
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "fake-chroot-ng";
  version = "1.1.0-unstable-2026-10-19";

  src = fetchFromGitHub {
    owner = "sylirre";
    repo = "fake-chroot-ng";
    rev = "b3ef8ae28a39837590d2065bf8cb0b6e1e32f8be";
    hash = "sha256-uWnEbjAgZdTOVC+OaaTYSWpEWDfeIse5R02UbbY7bVY=";
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
