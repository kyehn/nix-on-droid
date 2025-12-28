{
  lib,
  runCommand,
  nixDirectory,
  prootTermux,
  bash,
  config,
  initialPackageInfo,
}:

runCommand "bootstrap" { } ''
  mkdir --parents $out/{.l2s,bin,dev/shm,etc,root,tmp,usr/{bin,lib}}
  mkdir --parents $out/nix/var/nix/{profiles,gcroots}/per-user/nix-on-droid

  cp --recursive ${nixDirectory}/store $out/nix/store
  cp --recursive ${nixDirectory}/var $out/nix/var
  chmod --recursive u+w $out/nix

  ln --symbolic ${initialPackageInfo.bash}/bin/sh $out/bin/sh

  install -D --mode=0755 ${lib.getExe' prootTermux "proot-static"} $out/bin/proot-static

  cp ${config.environment.files.login} $out/bin/login
  cp ${config.environment.files.loginInner} $out/usr/lib/login-inner

  ${bash}/bin/bash ${../modules/environment/etc/setup-etc.sh} $out/etc ${config.build.activationPackage}/etc

  cp --dereference --recursive $out/etc/static $out/etc/.static.tmp
  rm $out/etc/static
  mv $out/etc/.static.tmp $out/etc/static

  find $out -executable -type f | sed s@^$out/@@ > $out/EXECUTABLES.txt

  find $out -type l | while read -r LINK; do
    LNK=''${LINK#$out/}
    TGT=$(readlink "$LINK")
    echo "$TGT←$LNK" >> $out/SYMLINKS.txt
    rm "$LINK"
  done
''
