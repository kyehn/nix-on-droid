{
  stdenv,
  fetchurl,
  python3,
  pkg-config,
  talloc,
  wafHook,
  writeText,
}:

stdenv.mkDerivation (finalAttrs: {
  inherit (talloc)
    pname
    version
    src
    wafPath
    preConfigure
    postInstall
    ;

  nativeBuildInputs = [
    pkg-config
    python3
    wafHook
  ];

  wafConfigureFlags = [
    "--disable-rpath"
    "--disable-python"
    "--cross-compile"
    "--cross-answers=${writeText "cross-answers.txt" ''
      Checking uname sysname type: "Linux"
      Checking uname machine type: "dontcare"
      Checking uname release type: "dontcare"
      Checking uname version type: "dontcare"
      Checking simple C program: OK
      building library support: OK
      Checking for large file support: OK
      Checking for -D_FILE_OFFSET_BITS=64: OK
      Checking for WORDS_BIGENDIAN: OK
      Checking for C99 vsnprintf: OK
      Checking for HAVE_SECURE_MKSTEMP: OK
      rpath library support: OK
      -Wl,--version-script support: FAIL
      Checking correct behavior of strtoll: OK
      Checking correct behavior of strptime: OK
      Checking for HAVE_IFACE_GETIFADDRS: OK
      Checking for HAVE_IFACE_IFCONF: OK
      Checking for HAVE_IFACE_IFREQ: OK
      Checking getconf LFS_CFLAGS: OK
      Checking for large file support without additional flags: OK
      Checking for working strptime: OK
      Checking for HAVE_SHARED_MMAP: OK
      Checking for HAVE_MREMAP: OK
      Checking for HAVE_INCOHERENT_MMAP: OK
      Checking getconf large file support flags work: OK
    ''}"
  ];

  preBuild = ''
    set +e
  '';

  postBuild = ''
    set -e
  '';

  installPhase = ''
    runHook preInstall

    mkdir --parents $out/lib $out/include
    cp talloc.h $out/include/
    find bin/default -name "*.o" -exec ${stdenv.cc.targetPrefix}nm -A {} + | grep " T rep_" | cut -d: -f1 | sort -u > found_objects.txt
    while read obj; do
      ${stdenv.cc.targetPrefix}ar rcs $out/lib/libtalloc.a "$obj"
    done < found_objects.txt

    runHook postInstall
  '';
})
