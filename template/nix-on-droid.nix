{
  lib,
  pkgs,
  ...
}:

{
  environment = {
    systemPackages = with pkgs; [ helix ];
    sessionVariables.EDITOR = "hx";
  };

  users.users.nix-on-droid.shell = lib.getExe pkgs.bash;
  # 固定占位 uid/gid，让同一份模板在不同构建者（CI runner 与各台 Android
  # 设备）上产出完全相同的 store 路径。users-groups.nix 默认用
  # builtins.exec [ "id" "-u" ] 取当前构建者的 uid，这会让
  # nixos-rebuild switch 的每一次构建都产生不同的 derivation 哈希，
  # 设备因此无法从 cachix 替换，只能全部本地重编。65534 是 bootstrapBuild
  # 已有的占位值，login-inner 的 setUser 会在启动时把它改写成真实 uid。
  users.users.nix-on-droid.uid = lib.mkForce 65534;
  users.groups.nix-on-droid.gid = lib.mkForce 65534;

  home-manager = {
    useGlobalPkgs = true;

    users.nix-on-droid =
      { lib, ... }:
      {
        home = {
          enableNixpkgsReleaseCheck = false;
          stateVersion = lib.trivial.release;
        };
        systemd.user.enable = false;
        programs.man = {
          enable = false;
          generateCaches = false;
        };
        manual = {
          html.enable = false;
          json.enable = false;
          manpages.enable = false;
        };
      };
  };
}
