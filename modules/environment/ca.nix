{
  pkgs,
  ...
}:

let
  certificate = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
in
{
  config = {
    environment.etc = {
      # NixOS canonical location + Debian/Ubuntu/Arch/Gentoo compatibility.
      "ssl/certs/ca-certificates.crt".source = certificate;
      # Old NixOS compatibility.
      "ssl/certs/ca-bundle.crt".source = certificate;
      # CentOS/Fedora compatibility.
      "pki/tls/certs/ca-bundle.crt".source = certificate;
    };
  };
}
