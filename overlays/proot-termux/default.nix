{
  lib,
  stdenv,
  fetchFromGitHub,
  talloc,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "proot-termux";
  version = "0-unstable-2026-07-10";

  src = fetchFromGitHub {
    repo = "proot";
    owner = "termux";
    rev = "87af48f58b752268cc4f93f251a9ca84e94c5655";
    hash = "sha256-ryqhMCOoPwJhqLXItQ34x+/v1Mvj0QcvxKYpv4Stu7s=";
  };

  patches = [
    ./detranslate-empty.patch
    ./syscall-support-fchmodat2.patch
  ];

  # Apply source modifications to fix loader bloat, seccomp offsets, and 32-bit linker errors.
  postPatch =
    # Use target-prefixed readelf for cross-compilation reliability
    ''
      substituteInPlace src/GNUmakefile \
        --replace-fail "readelf -s" "${stdenv.cc.targetPrefix}readelf -s"
    ''
    # --- Completely remove 32-bit support to fix pure 64-bit musl linking issues ---

    # 1. Strip the 32-bit loader build instructions from GNUmakefile.
    # This prevents `ld` from failing when trying to link 64-bit libunwind into a 32-bit loader.
    + ''
      sed -i '/loader-m32/d' src/GNUmakefile
    ''
    # 2. Disable 32-bit loader fallback logic in the C codebase
    + ''
      substituteInPlace src/arch.h \
        --replace-fail '#define HAS_LOADER_32BIT true' '#define HAS_LOADER_32BIT false'
    ''
    # 3. Fix seccomp rules for x86_64: reduce nb_abis from 2 to 1 and remove the 32-bit ABI entry
    + ''
      substituteInPlace src/arch.h \
        --replace-fail '.nb_abis = 2, .abis = { ABI_DEFAULT, ABI_3 }' '.nb_abis = 1, .abis = { ABI_DEFAULT }'
    ''
    # 4. Remove seccomp fallback rules and secondary ABIs from ALL architectures
    # This completely halts BPF instruction generation for non-default ABIs.
    + ''
      sed -i '/\.abis = { ABI_2 }/d' src/arch.h
      sed -i '/#define SYSNUMS_HEADER2/d' src/arch.h
      sed -i '/#define SYSNUMS_HEADER3/d' src/arch.h
      sed -i '/#define SYSNUMS_ABI2/d' src/arch.h
      sed -i '/#define SYSNUMS_ABI3/d' src/arch.h
    ''
    # 5. Strict bash assertions to ensure nothing was missed during patching
    + ''
      if grep -q "\.nb_abis = 2" src/arch.h; then
        echo "Error: Failed to patch multi-ABI seccomp rules! Check src/arch.h"
        exit 1
      fi
      if grep -q "SYSNUMS_ABI2" src/arch.h; then
        echo "Error: Secondary 32-bit SYSNUMS_ABI2 macros still exist! Check src/arch.h"
        exit 1
      fi
    ''
    # --- Add fchmodat2 syscall number to all architecture tables ---
    # The syscall-support-fchmodat2.patch handles enter.c, seccomp.c, and
    # sysnums.list, but the sysnums*.h patches fail because upstream changed
    # indentation (spaces -> tabs) and added new entries.  Use sed with a
    # shell-embedded tab ($(printf '\t')) to avoid regex escaping issues.
    + ''
      tab=$(printf '\t')
      sed -i "/^''${tab}\[ 437 \] = PR_openat2,$/a''${tab}[ 452 ] = PR_fchmodat2," src/syscall/sysnums-arm.h
      sed -i "/^''${tab}\[ 439 \] = PR_faccessat2,$/a''${tab}[ 452 ] = PR_fchmodat2," src/syscall/sysnums-arm64.h
      sed -i "/^''${tab}\[ 439 \] = PR_faccessat2,$/a''${tab}[ 452 ] = PR_fchmodat2," src/syscall/sysnums-sh4.h
      sed -i "/^''${tab}\[ 437 \] = PR_openat2,$/a''${tab}[ 452 ] = PR_fchmodat2," src/syscall/sysnums-x32.h
      sed -i "/^''${tab}\[ 439 \] = PR_faccessat2,$/a''${tab}[ 452 ] = PR_fchmodat2," src/syscall/sysnums-x86_64.h
    ''

    # --- Prevent 128GB loader bloat on AArch64 (LLVM 17 -> 21 regression) ---
    # Core Fix: Only apply the -n linker flag and p_align patch on AArch64.
    # Applying `-n` on x86_64 breaks the ELF loader segment layout and causes SIGSEGV (signal 11).
    + lib.optionalString stdenv.hostPlatform.isAarch64 ''
      substituteInPlace src/GNUmakefile \
        --replace-fail ",-Ttext" ",-n,-Ttext" \
        --replace-fail '$$(Q)cp $$< $$@' '$$(Q)cp $$< $$@ && printf '"'"'\x00\x00\x01\x00\x00\x00\x00\x00'"'"' | dd of=$$@ bs=1 seek=112 count=8 conv=notrunc 2>/dev/null'
    '';

  # Generate mocked ashmem header for proot internals
  preConfigure = ''
    mkdir --parents fake-ashmem/linux
    cat > fake-ashmem/linux/ashmem.h << EOF
    #include <linux/limits.h>
    #include <sys/ioctl.h>
    #include <string.h>
    #include <errno.h>
    #include <unistd.h>
    #define __ASHMEMIOC 0x77
    #define ASHMEM_NAME_LEN 256
    #define ASHMEM_SET_NAME _IOW(__ASHMEMIOC, 1, char[ASHMEM_NAME_LEN])
    #define ASHMEM_SET_SIZE _IOW(__ASHMEMIOC, 3, size_t)
    #define ASHMEM_GET_SIZE _IO(__ASHMEMIOC, 4)
    EOF
  '';

  buildInputs = [ talloc ];

  enableParallelBuilding = true;

  makeFlags = [
    "-Csrc"
    "V=1"
  ];

  # Optimize compiler outputs, apply Android stubs, and silence noisy upstream warnings
  CFLAGS = [
    "-O3"
    "-pipe"
    "-fomit-frame-pointer"
    "-w" # Silence all compiler warnings to keep the build log clean
    "-I../fake-ashmem"
    "-D_LARGEFILE64_SOURCE"
    "-DMSG_COPY=040000"
    "'-DTEMP_FAILURE_RETRY(exp)=({ __typeof__(exp) _rc; do { _rc = (exp); } while (_rc == -1 && errno == EINTR); _rc; })'"
    "-D__ANDROID__"
    "-DTCGETS=0x5401"
    "-DTCSETS=0x5402"
    "-DTCSETSW=0x5403"
    "-DTCSETSF=0x5404"
    "-DTCGETS2=0x802C542A"
    "-DTCSETS2=0x402C542B"
    "-DTCSETSW2=0x402C542C"
    "-DTCSETSF2=0x402C542D"
  ]
  ++ lib.optionals stdenv.hostPlatform.isStatic [ "-static" ];

  LDFLAGS = lib.optionals stdenv.hostPlatform.isStatic [ "-static" ];

  hardeningDisable = [
    "fortify"
    "zerocallusedregs"
  ];

  installPhase = ''
    runHook preInstall

    ${stdenv.cc.targetPrefix}strip src/proot
    install -D --mode=0755 src/proot $out/bin/${finalAttrs.meta.mainProgram}

    runHook postInstall
  '';

  doInstallCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;

  installCheckPhase = ''
    runHook preInstallCheck

    PROOT_BIN="$out/bin/${finalAttrs.meta.mainProgram}"
    "$PROOT_BIN" --help
    "$PROOT_BIN" -b /:/ sh -c "echo 'Seccomp works'"
    echo "NixOS-spoofed" > spoofed_content.txt
    "$PROOT_BIN" -b spoofed_content.txt:/etc/fake_spoof.txt sh -c "cat /etc/fake_spoof.txt"
    "$PROOT_BIN" -R / -0 sh -c "id -u"

    runHook postInstallCheck
  '';

  meta.mainProgram = "proot";
})
