{
  bash,
  uutils-coreutils-noprefix,
  nix,
  runCommand,
}:

runCommand "nix-on-droid"
  {
    preferLocalBuild = true;
    allowSubstitutes = false;
    meta.mainProgram = "nix-on-droid";
  }
  ''
    install -D --mode=0755  ${./nix-on-droid.sh} $out/bin/nix-on-droid

    substituteInPlace $out/bin/nix-on-droid \
      --subst-var-by bash "${bash}" \
      --subst-var-by coreutils "${uutils-coreutils-noprefix}" \
      --subst-var-by nix "${nix}"
  ''
