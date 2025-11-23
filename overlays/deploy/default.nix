{
  lib,
  bash,
  coreutils,
  git,
  gnugrep,
  gnused,
  gnutar,
  gzip,
  jq,
  nix,
  openssh,
  rsync,
  runCommand,
}:

runCommand "deploy"
  {
    preferLocalBuild = true;
    allowSubstitutes = false;
    meta.mainProgram = "deploy";
  }
  ''
    install -D --mode=0755  ${./deploy.sh} $out/bin/deploy

    substituteInPlace $out/bin/deploy \
      --subst-var-by bash "${bash}" \
      --subst-var-by path "${
        lib.makeBinPath [
          coreutils
          git
          gnugrep
          gnused
          gnutar
          gzip
          jq
          nix
          openssh
          rsync
        ]
      }"
  ''
