{
  lib,
  runCommand,
  bootstrapClosureInfo,
  config,
  nix,
  smfh,
  substitute,
}:

let
  smfhManifest = config.system.build.smfhManifest;
in
runCommand "bootstrap"
  {
    __structuredAttrs = true;
    unsafeDiscardReferences.out = true;

    env = {
      NIX_REMOTE = "local";
      NIX_STATE_DIR = "${placeholder "out"}/nix/var/nix";
      NIX_LOG_DIR = "${placeholder "out"}/nix/var/log";
    };
  }
  ''
    mkdir --parents $out/{.l2s,bin,root,tmp,run,var,usr/bin,nix/store}
    mkdir --parents $out/nix/var/nix/gcroots $out/nix/var/nix/profiles
    ln --symbolic --no-dereference ${config.system.build.toplevel} $out/run/current-system
    ln --symbolic --no-dereference ${config.system.build.toplevel} $out/nix/var/nix/gcroots/current-system
    ln --symbolic --no-dereference ${config.system.build.toplevel} $out/nix/var/nix/profiles/system

    xargs cp --archive --target-directory=$out/nix/store < ${bootstrapClosureInfo}/store-paths
    ${nix}/bin/nix-store --init
    ${nix}/bin/nix-store --load-db < ${bootstrapClosureInfo}/registration
    chmod --recursive u+w $out/nix

    cp --dereference --recursive ${config.system.build.etc} $out/etc
    substitute ${smfhManifest} ./smfh-manifest-bootstrap.json --subst-var out
    ${lib.getExe smfh} activate ./smfh-manifest-bootstrap.json

    find "$out" -type f -executable -printf '%P\n' > "$out/EXECUTABLES.txt"

    find "$out" -type l -printf '%P\n' | while read -r rel; do
      target=$(readlink "$out/$rel")
      clean_target=$(echo "$target" | sed "s|^$out||")
      echo "''${clean_target}←''${rel}"
      rm "$out/$rel"
    done > "$out/SYMLINKS.txt"
  ''
