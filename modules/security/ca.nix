{
  pkgs,
  ...
}:

{
  config.environment.etc = {
    # NixOS canonical location + Debian/Ubuntu/Arch/Gentoo compatibility.
    "ssl/certs/ca-certificates.crt".source = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

    # Old NixOS compatibility.
    "ssl/certs/ca-bundle.crt".source = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

    # CentOS/Fedora compatibility.
    "pki/tls/certs/ca-bundle.crt".source = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  };
}
