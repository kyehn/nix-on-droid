{
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "chroot-ng";
  version = "0-unstable-2026-11-19";

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchFromGitHub {
    owner = "sylirre";
    repo = "arm64emu";
    rev = "c3527a0c513e264b0583ca0f38a4140d7b67cacf";
    hash = "sha256-Lg92ncdwmWQ25EQZsLvLq2g1+SOkzkeGGL/zfrpcFqQ=";
  };

  patches = [
    ./fix-unfollowed-magic-links.patch
    # The emulated execve wound the guest's brk heap back to the break it had
    # before any guest program ran, which unmapped the live SIGSYS signal
    # frame the exec returns through (the guest's alternate signal stack is a
    # chunk of that very heap). The exec then wrote the new program's
    # registers into unmapped memory: SIGSEGV on the first exec, which closed
    # the build hook's reply pipe with zero bytes -- nix's "unexpected EOF
    # reading a line". The shrink now stops at the top of every live signal
    # frame instead of at the initial break. The frame is found by asking
    # whether it lies inside the alternate signal stack its ucontext names:
    # SS_ONSTACK says only that the interrupted stack pointer was on that
    # stack, which is false for a trap taken on the thread's ordinary stack.
    ./fix-exec-brk-shrink-signal-frame.patch
  ];

  buildTarget = "chroot-ng";

  env.CHROOTNG_CFLAGS = "-Werror";

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
