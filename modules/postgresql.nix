{ pkgs, lib, ... }: {

services.postgresql = {
  enable = true;
  package = pkgs.postgresql_16;
  settings = {
    listen_addresses = lib.mkForce "*";
    port = 5432;
  };
  authentication = ''
    local all all trust
    host all all 192.168.5.0/24 trust
    host all all ::1/128 trust
  '';
};
networking.firewall.allowedTCPPorts = [ 5432 ];
}
