{ ... }:
{
  virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "docker";
  systemd.tmpfiles.rules = [
    "d /var/lib/snappymail 0750 root root - -"
  ];
  virtualisation.oci-containers.containers.snappymail = {
    image = "djmaze/snappymail:latest";
    ports = [ "80:8888" ];
    volumes = [ "/var/lib/snappymail:/var/lib/snappymail" ];
  };

  networking.firewall.allowedTCPPorts = [ 80 ];

}
