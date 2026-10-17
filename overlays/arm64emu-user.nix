{
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "arm64emu-user";
  version = "1.6.0-unstable-2026-10-14";

  src = fetchFromGitHub {
    owner = "sylirre";
    repo = "arm64emu-user";
    rev = "90fe88ca71794d29eecddc4b8925d68b79a2c342";
    hash = "sha256-cmDRNtFqIdEzH2gxHHpuRqsBUir9etHomYjcV/WrQck=";
  };

  CFLAGS = [
    "-O2"
    "-pipe"
    "-D__ANDROID__"
  ];

  installPhase = ''
    runHook preInstall

    install -D --mode=0755 ${finalAttrs.meta.mainProgram} $out/bin/${finalAttrs.meta.mainProgram}
    ${stdenv.cc.targetPrefix}strip --strip-unneeded $out/bin/${finalAttrs.meta.mainProgram}

    runHook postInstall
  '';

  meta = {
    mainProgram = "arm64chroot";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "i686-linux"
      "armv7l-linux"
    ];
  };
})
