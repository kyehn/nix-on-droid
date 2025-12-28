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
  ${lib.getExe zip} -q -9 -r $out/bootstrap-${stdenv.hostPlatform.parsed.cpu.name} ./* ./.l2s
''
