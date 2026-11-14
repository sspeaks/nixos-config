{ config, inputs, ... }:
# The todo-tui daemon (github:sspeaks/todo-tui), reachable only on the tailnet:
# the module serves it on 127.0.0.1:7743 and `tailscale serve` puts HTTPS in
# front of it at https://vidbox.<tailnet>.ts.net. The tailnet needs MagicDNS
# and HTTPS certificates turned on.
#
# Pair a device: `sudo todo-tui-admin remote pair --name <device>`.
{
  imports = [ inputs.todo-tui.nixosModules.default ];

  # A Tailscale OAuth client secret (tskey-client-...), which does not expire
  # like an auth key does. The client needs the `auth_keys` write scope with
  # tag:server, and nodes it registers must advertise that tag.
  # tailscaled-autoconnect uses it only when the node is logged out.
  sops.secrets.tailscale-oauth-secret = {
    format = "yaml";
    sopsFile = ../../secrets/vidbox.yaml;
    mode = "0400";
  };

  services.tailscale = {
    enable = true;
    authKeyFile = config.sops.secrets.tailscale-oauth-secret.path;
    authKeyParameters = {
      ephemeral = false;
      preauthorized = true;
    };
    extraUpFlags = [ "--advertise-tags=tag:server" ];
  };

  services.todo-tui = {
    enable = true;
    tailscaleServe = true;
    timeZone = config.time.timeZone;
  };
}
