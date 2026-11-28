{
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "arm64emu";
  version = "0-unstable-2026-11-27";

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchFromGitHub {
    owner = "sylirre";
    repo = "arm64emu";
    rev = "005ff79089ff68deb2cdcde26e808be18329f367";
    hash = "sha256-OZglcjgBg8XYdlz9o6zN1yoF2xPyXHZvnWwVsQSUjIk=";
  };

  patches = [
    ./fix-unfollowed-magic-links.patch
    # The emulated execve used to wind the guest's brk heap back to the break it
    # had before any guest program ran, which unmapped the live SIGSYS signal
    # frame the exec returned through (the guest's alternate signal stack is a
    # chunk of that very heap). Upstream now reclaims the heap in the exec
    # sweep; the patch keeps every mapping holding a live frame out of it. The
    # frame is found by asking whether it lies inside the alternate signal
    # stack its ucontext names: SS_ONSTACK says only that the interrupted stack
    # pointer was on that stack, which is false for a trap taken on the
    # thread's ordinary stack.
    ./fix-exec-sweep-signal-frame.patch
  ];

  buildTarget = "arm64emu";

  env = {
    ARM64EMU_NATIVE_CFLAGS = "-Werror";
    # A non-PIE arm64emu occupies the low addresses that ET_EXEC guests such
    # as login-inner are linked at; a static PIE leaves them free for the
    # native tier instead of falling back to the emulator.
    NIX_CFLAGS_COMPILE = "-fPIE";
    NIX_CFLAGS_LINK = "-static-pie";
  };

  installPhase = ''
    runHook preInstall

    install -D --mode=0755 build/${finalAttrs.meta.mainProgram} $out/bin/${finalAttrs.meta.mainProgram}
    ${stdenv.cc.targetPrefix}strip --strip-unneeded $out/bin/${finalAttrs.meta.mainProgram}

    runHook postInstall
  '';

  meta = {
    mainProgram = "arm64emu";
    platforms = [ "aarch64-linux" ];
  };
})
