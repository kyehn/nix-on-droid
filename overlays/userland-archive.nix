{
  lib,
  runCommand,
  userland,
  gnutar,
  xz,
}:

runCommand "userland-archive"
  {
    nativeBuildInputs = [
      gnutar
      xz
    ];
  }
  ''
    mkdir "$out"
    tar --create --file - \
      --numeric-owner --owner=0 --group=0 \
      --sort=name --mtime=@0 --no-xattrs \
      --directory "${userland}" . \
      | xz --compress -9 -T0 \
      > "$out/userland.tar.xz"
  ''
