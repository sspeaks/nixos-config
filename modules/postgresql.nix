{ pkgs, lib, ... }: {

  # WARNING: This PostgreSQL configuration uses 'trust' authentication and listens on all interfaces.
  # This is INSECURE and should only be used in trusted, isolated environments.
  # For production use, consider:
  #   - Using 'md5' or 'scram-sha-256' authentication instead of 'trust'
  #   - Restricting listen_addresses to specific IPs (e.g., "localhost" or "192.168.5.10")
  #   - Using firewall rules to limit access to specific hosts

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    settings = {
      listen_addresses = lib.mkDefault "*";
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
