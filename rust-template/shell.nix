{ pkgs, toolchain, ... }:
pkgs.mkShell {
  packages = [
    toolchain
    pkgs.pkg-config
    # Common native deps live behind pkg-config; uncomment as needed:
    # pkgs.openssl
  ];
  shellHook = ''
    echo "$(rustc --version)"
  '';
}
