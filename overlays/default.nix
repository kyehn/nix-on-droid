{
  inputs,
  ...
}:

final: prev:
let
  pkgs-android-args = {
    inherit (prev.stdenv.hostPlatform) system;
    crossSystem = {
      config = "${prev.stdenv.hostPlatform.cpu}-unknown-linux-android";
      sdkVer = "36";
      androidSdkVersion = "36";
      androidNdkVersion = "r27d";
      libc = "bionic";
      useAndroidPrebuilt = false;
      useLLVM = true;
      isStatic = true;
    };
  };

  pkgs-android = import (prev.applyPatches {
    name = "nixpkgs-crosscompilation";
    src = inputs.nixpkgs;
    patches = [ ./compiler-rt.patch ];
    postPatch = ''
      substituteInPlace pkgs/development/compilers/llvm/common/compiler-rt/default.nix \
        --replace-fail 'ln -s $out/lib/*/clang_rt.crtbegin-*.o $out/lib/crtbeginS.o' "" \
        --replace-fail 'ln -s $out/lib/*/clang_rt.crtend-*.o $out/lib/crtendS.o' "" \
        --replace-fail '"dev"' ""
       sed -i '/cmakeFlags/i LDFLAGS = "-unwindlib=none";' pkgs/development/compilers/llvm/common/libunwind/default.nix
    '';
  }) pkgs-android-args;

  pkgs-proot-termux = import (prev.applyPatches {
    name = "nixpkgs-proot-termux";
    src = inputs.nixpkgs-proot-termux;
    postPatch = ''
      substituteInPlace pkgs/development/compilers/llvm/common/compiler-rt/default.nix \
        --replace-fail 'ln -s $out/lib/*/clang_rt.crtbegin-*.o $out/lib/crtbeginS.o' "" \
        --replace-fail 'ln -s $out/lib/*/clang_rt.crtend-*.o $out/lib/crtendS.o' "" \
        --replace-fail '"dev"' ""
       sed -i '/cmakeFlags/i LDFLAGS = "-unwindlib=none";' pkgs/development/compilers/llvm/common/libunwind/default.nix
    '';
  }) pkgs-android-args;

  modules = import ../modules {
    pkgs = prev;
    targetSystem = prev.stdenv.hostPlatform.system;

    isFlake = true;

    config = {
      imports = [ ../modules/build/initial-build.nix ];

      _module.args = {
        inherit (final) initialPackageInfo;
        pkgs = prev.lib.mkForce prev; # to override ./modules/nixpkgs/config.nix
      };

      system.stateVersion = "25.11";

      # Fix invoking bash after initial build.
      user.shell = "${final.initialPackageInfo.bash}/bin/bash";
    };
  };
in
{
  deploy = prev.callPackage ./deploy { };
  nix-on-droid = prev.callPackage ./nix-on-droid { };
  termux-am = prev.callPackage ./termux-am.nix { };
  termux-tools = prev.callPackage ./termux-tools { };
  onetbb = prev.onetbb.overrideAttrs (oldAttrs: {
    doCheck = if prev.stdenv.hostPlatform.isStatic then false else oldAttrs.doCheck;

    cmakeFlags =
      oldAttrs.cmakeFlags ++ (if prev.stdenv.hostPlatform.isStatic then [ "-DTBB_TEST=OFF" ] else [ ]);
  });
  nixDirectory = prev.callPackage ./nix-directory.nix {
    inherit system;
    inherit (modules) config;
    inherit (final) prootTermux;
  };
  initialPackageInfo = import "${final.nixDirectory}/nix-support/package-info.nix";
  bootstrap = prev.callPackage ./bootstrap.nix {
    inherit (modules) config;
    inherit (final) prootTermux initialPackageInfo;
  };
  bootstrapZip = prev.callPackage ./bootstrap-zip.nix { targetSystem = system; };
  prootTermux = pkgs-proot-termux.callPackage ./proot-termux {
    talloc = final.tallocStatic;
    stdenv = pkgs-proot-termux.stdenvAdapters.makeStaticBinaries pkgs-proot-termux.stdenv;
  };
  tallocStatic = pkgs-android.callPackage ./talloc-static.nix { };
}
