{
  lib,
  stdenv,
  runCommand,
  zip,
  bootstrap,
}:

runCommand "bootstrap-zip" { } ''
  mkdir $out
  cd ${bootstrap}
  ${lib.getExe zip} -q -9 -r $out/bootstrap-${stdenv.hostPlatform.cpu} ./* ./.l2s
''
