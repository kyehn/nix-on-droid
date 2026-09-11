{
  lib,
  stdenv,
  runCommand,
  zip,
  bootstrap,
}:

runCommand "bootstrap-zip" { } ''
  mkdir "$out"
  cd "${bootstrap}"
  find . -mindepth 1 -maxdepth 1 -print0 | xargs -0 ${lib.getExe zip} --quiet -9 -r "$out"/bootstrap-${stdenv.hostPlatform.parsed.cpu.name}.zip
''
