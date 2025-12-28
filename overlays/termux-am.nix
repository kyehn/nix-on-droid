{
  stdenv,
  fetchFromGitHub,
  cmake,
}:

stdenv.mkDerivation (finalAttrs: {
  name = "termux-am";
  version = "1.5.0";

  src = fetchFromGitHub {
    owner = "termux";
    repo = "termux-am-socket";
    tag = finalAttrs.version;
    hash = "sha256-6pCv2HMBRp8Hi56b43mQqnaFaI7y5DfhS9gScANwg2I=";
  };

  # Header generation doesn't seem to work on android
  postPatch = ''
    echo "#define SOCKET_PATH \"/data/data/com.termux.nix/files/apps/com.termux.nix/termux-am/am.sock\"" > termux-am.h.in
  ''
  # Fix the bash link so that nix can patch it + path to termux-am-socket
  + ''
    substituteInPlace termux-am.sh.in \
      --replace-fail "@TERMUX_PREFIX@/bin/bash" "/bin/bash" \
      --replace-fail 'termux-am-socket "$am_command_string"' "$out/bin/termux-am-socket \"\$am_command_string\""
  '';

  nativeBuildInputs = [ cmake ];

  # Scripts use 'am' as an alias.
  postInstall = ''
    ln --symbolic $out/bin/termux-am $out/bin/am
  '';

  meta.mainProgram = "am";
})
