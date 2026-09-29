{
  lib,
  stdenv,
  fetchFromGitHub,
  talloc,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "proot-termux";
  version = "5.1.107.96-unstable-2026-10-01";

  src = fetchFromGitHub {
    repo = "proot";
    owner = "termux";
    rev = "a179d3e8a4e045aaa1fb8cc3284f23509d96d353";
    hash = "sha256-X9VvBaFSUq545adQ6/f8Wp/TM7XTXNJp/QGwprabsVw=";
  };

  patches = [
    # Build for a pure 64-bit static target: drop the secondary 32-bit
    # ABI tables and the -m32 loader (details in the patch header).
    ./strip-32bit-support.patch
    # ...and say so instead of letting a 32-bit guest die on a SIGSEGV
    # with no explanation.
    ./reject-32bit-guests.patch
    # Let the environment own -O: the makefile's hardcoded -O2 used to
    # silently downgrade the CFLAGS optimization level.
    ./build-let-env-own-opt-level.patch
    ./syscall-support-fchmodat2.patch
    # Per-arch fchmodat2 numbers (452); the main patch covers enter.c,
    # seccomp.c and sysnums.list.
    ./syscall-support-fchmodat2-sysnums.patch
    # Android untrusted_app seccomp compatibility: proot's own blocked
    # libc calls (fork, access, mkdir, unlink, ...).
    ./android-seccomp-self-compat.patch
    # ...and the enter-stop rewrite that converts guest syscalls the
    # zygote KILL filter forbids before the filter ever evaluates them.
    ./android-seccomp-guest-rewrite.patch
    # Android untrusted_app denies RTM_GETLINK (nlmsg_readpriv) and
    # netlink bind(2), so getifaddrs(3) fails and the fake-netlink
    # replies degraded to loopback-only -- nix then saw "no Internet"
    # and disabled all substituters.  Answer RTM_GETLINK / RTM_GETADDR
    # from an RTM_GETADDR dump plus SIOCGIF* ioctls instead.
    ./fake-netlink-addr-relay.patch
    # Keep every synthetic stack adjustment 16-byte aligned on AArch64.
    ./stack-alignment.patch
    # Preserve the shell status when a tracee is terminated by a signal.
    ./signal-exit-status.patch

    # --- Backports from proot-me/proot, absent from the termux fork ---
    # The termux fork rebased onto a v5.1.0-era base and carries its own
    # rewrite of the seccomp/tracee layer, so these are applied as focused
    # patches instead of switching forks.

    # getresuid(2)/getresgid(2) write 32-bit uid_t/gid_t; poking only 16 bits
    # left the upper half of each caller's uid_t uninitialised on LP64.
    ./fix-fake-id0-32bit-res-ids.patch
    # The extracted loader must stay executable by tracees running as any uid,
    # otherwise the fake-id0 extension cannot drop privileges.
    ./fix-loader-executable-by-any-uid.patch
    # readlink() of a top-level /proc entry ("/proc/self", "/proc/device-tree")
    # hit a wrong-comparison assert; ARM firmware makes the latter common.
    ./fix-readlink-proc-toplevel-entries.patch
    # Unix socket paths longer than sun_path are rebound through a private
    # temp directory instead of an racy mktemp(3) file name.
    ./fix-unix-socket-sun-path-length.patch
    # A ptracer waiting on a ptracee that is already a proot zombie got no
    # emulated event and blocked forever.
    ./fix-ptrace-wait-zombie-ptracee.patch
    # canonicalize() skipped binding substitution and HOST_PATH extensions
    # for the initial "/" component of every user path.
    ./fix-canon-root-binding-substitution.patch
    # kompat rejected unknown fstatat(2) flags even on kernels that need no
    # patching at all, breaking stat() for any new flag.
    ./fix-kompat-fstatat-flag-validation.patch
    # --mixed-mode: run every ELF through emulation instead of passing
    # host-native executables straight to the kernel.
    ./add-mixed-mode-option.patch
    # Restarting the original syscall resets registers/trap directly
    # instead of queuing through chained syscalls, so an intervening
    # signal cannot confuse the chain bookkeeping.
    ./fix-restart-syscall-no-chain.patch
    # A restarted wait must not poke SYSARG_RESULT: on ARM it shares a
    # register with SYSARG_1 and would corrupt the wait pid argument.
    ./fix-wait-exit-no-clobber-args.patch
    # PTRACE_O_TRACESECCOMP is rejected under ptrace emulation; proot
    # never forwards seccomp traps, so fail loudly instead of hanging.
    ./fix-ptrace-traceseccomp-einval.patch
    # PTRACE_PEEKDATA returns data in-band, so errno must be cleared
    # before each call; a stale errno left by the process_vm_* fast path
    # would otherwise turn into a bogus -EFAULT on the ptrace fallback.
    ./fix-peekdata-clear-errno.patch
    # substitute_binding_stat() collapsed every access failure to -ENOENT;
    # report the real errno (EACCES, ...) so guests see faithful errors.
    # NOTE: must sort after android-seccomp-self-compat.patch above, which
    # renames lstat() to ac_lstat(); this patch's context expects ac_lstat.
    ./fix-canon-errno-fidelity.patch
    # readlinkat(AT_EMPTY_PATH) passes an empty referrer; detranslate
    # must return early (ports proot-me/proot 413abd6, details inside).
    ./fix-detranslate-empty-referrer.patch
    # Centralize MSG_COPY/TC*/TEMP_FAILURE_RETRY/ashmem fallbacks in
    # src/compat.h (details inside); drops fake-ashmem/preConfigure.
    ./compat-libc-kernel-fallbacks.patch
  ];

  # Everything that can be a patch is a patch; what remains here is what
  # a static patch cannot express: Nix-time values (the cross readelf
  # prefix) and platform-conditional edits (the AArch64 loader fixup).
  postPatch =
    # Use target-prefixed readelf for cross-compilation reliability.
    # (Kept as substituteInPlace: the prefix is a Nix-time value that a
    # static patch cannot express.)
    ''
      substituteInPlace src/GNUmakefile \
        --replace-fail "readelf -s" "${stdenv.cc.targetPrefix}readelf -s"
    ''

    # --- Assert loader segment layout on AArch64 ---
    # LLVM lld page-aligns PT_LOAD up to 64K on AArch64, padding the tiny
    # static loader (this bloat is then baked into proot via objcopy).
    # NOTE: do NOT pass `-n` (nmagic) here: with current lld it merges
    # the segments into a single PT_LOAD whose p_offset (0xb0) is not
    # page-aligned, so proot's page-masked mmap maps the ELF header over
    # the entry point and the guest dies with SIGSEGV on first exec.
    # (The old `-n` hack predates the current toolchain, where the
    # unpadded loader is only ~67K.)  fix-loader-align.sh asserts the
    # loader layout instead of rewriting it: it fails loudly on
    # p_align > 64K or on offset/vaddr incongruence.
    + lib.optionalString stdenv.hostPlatform.isAarch64 ''
      substituteInPlace src/GNUmakefile \
        --replace-fail '$$(Q)cp $$< $$@' '$$(Q)cp $$< $$@ && ${./fix-loader-align.sh} ${stdenv.cc.targetPrefix}readelf $$@'
    '';

  buildInputs = [ talloc ];

  enableParallelBuilding = true;

  makeFlags = [
    "-Csrc"
    "V=1"
  ];

  # Optimization level is ours now: build-let-env-own-opt-level.patch
  # drops the makefile's hardcoded -O2 (which used to win as the last -O).
  # The -D shims that used to live here (MSG_COPY, TCGETS*, TEMP_FAILURE_RETRY,
  # <linux/ashmem.h> via -I../fake-ashmem) moved into src/compat.h as guarded
  # fallbacks (compat-libc-kernel-fallbacks.patch).  -fomit-frame-pointer
  # (redundant at -O3, and it makes on-device proot crashes harder to
  # backtrace) and the duplicate -static (meaningless in a -c compile;
  # LDFLAGS below owns it) are gone too.  -w is replaced with hard errors
  # for the bug classes that matter (implicit declarations, missing
  # return values); remaining upstream warnings stay visible.
  # (Note: -Wno-* would be useless here: the makefile appends -Wall -Wextra
  # after the environment CFLAGS, re-enabling whatever we silence.)
  CFLAGS = [
    "-O3"
    "-pipe"
    # musl only declares struct rlimit64/prlimit64 (used by
    # syscall/rlimit.c) under _LARGEFILE64_SOURCE; harmless elsewhere.
    # (Feature-test macro: must stay a command-line -D, compat.h is too late.)
    "-D_LARGEFILE64_SOURCE"
    "-Werror=implicit-function-declaration"
    "-Werror=implicit-int"
    "-Werror=return-type"
  ]
  ++ [
    # Unconditional: the x86_64 installCheck exercises the same Android
    # code paths (ioctl downgrade, ashmem, /system ldso) that the
    # aarch64 device build runs.  Gating this on isAarch64 would test a
    # different branch than the device executes.
    "-D__ANDROID__"
  ];

  LDFLAGS = lib.optionals stdenv.hostPlatform.isStatic [ "-static" ];

  # fortify: the -nostdlib loader blob has no fortified libc; several
  # patches use strcpy/strcat/snprintf that _FORTIFY_SOURCE turns into
  # errors.  zerocallusedregs: its register-zeroing prologue breaks the
  # hand-written loader entry.  pic/pie/stackprotector stay enabled: the
  # loader builds -fPIC already, links without -pie (fixed -Ttext needs
  # it), and musl static provides __stack_chk_fail.
  hardeningDisable = [
    "fortify"
    "zerocallusedregs"
  ];

  installPhase = ''
    runHook preInstall

    # Install first, then strip the installed copy: stripping the build
    # tree in place breaks rebuilds and needlessly mutates the source dir.
    install -D --mode=0755 src/proot $out/bin/${finalAttrs.meta.mainProgram}
    ${stdenv.cc.targetPrefix}strip --strip-unneeded $out/bin/${finalAttrs.meta.mainProgram}

    runHook postInstall
  '';

  doInstallCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;

  installCheckPhase = ''
    runHook preInstallCheck

    PROOT_BIN="$out/bin/${finalAttrs.meta.mainProgram}"
    "$PROOT_BIN" --help
    test "$("$PROOT_BIN" -b /:/ sh -c "echo 'works'")" = works
    echo "spoofed" > spoofed_content.txt
    test "$("$PROOT_BIN" -b spoofed_content.txt:/etc/fake_spoof.txt sh -c "cat /etc/fake_spoof.txt")" = spoofed
    test "$("$PROOT_BIN" -R / -0 sh -c "id -u")" = 0
  ''
  # chmod through the guest exercises the *at chmod family translation
  # (fchmodat/fchmodat2 incl. the per-arch tables); glibc >= 2.43 issues
  # fchmodat2 here, older libcs fchmodat — both must yield mode 600.
  + ''
    "$PROOT_BIN" -b /:/ sh -c "touch proot_chmod_probe && chmod 600 proot_chmod_probe && stat -c %a proot_chmod_probe | grep -q '^600$'"
    rm -f proot_chmod_probe

    runHook postInstallCheck
  '';

  meta.mainProgram = "proot";
})
