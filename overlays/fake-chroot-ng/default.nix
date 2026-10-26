{
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "fake-chroot-ng";
  version = "1.5.0-unstable-2026-10-25";

  src = fetchFromGitHub {
    owner = "sylirre";
    repo = "fake-chroot-ng";
    rev = "9afe1d5361d633f0dea8e8fffac3fe7f0d31d622";
    hash = "sha256-thcJZDr4XBTSHuGUz3r4JbCTWJpZ/9OxmlqmF2WYI+w=";
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
