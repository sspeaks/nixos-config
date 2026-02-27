{ pkgs, lib, ... }:
let
  # Helper script to adjust bandwidth limits on the fly
  setBandwidth = pkgs.writeShellScriptBin "set-bandwidth" ''
    if [ $# -ne 2 ]; then
      echo "Usage: set-bandwidth <download_mbps> <upload_mbps>"
      echo "Example: set-bandwidth 50 20"
      echo ""
      echo "Current status:"
      ${pkgs.iproute2}/bin/tc -s qdisc show dev wlan0 2>/dev/null || echo "  No qdisc on wlan0"
      exit 1
    fi

    DOWN="$1"
    UP="$2"

    echo "Setting bandwidth limits: download=''${DOWN}mbit upload=''${UP}mbit"
    ${pkgs.iproute2}/bin/tc qdisc replace dev wlan0 root cake bandwidth "''${DOWN}mbit" nat wash diffserv4 flowblind
    ${pkgs.iproute2}/bin/tc qdisc replace dev ifb-wan root cake bandwidth "''${UP}mbit" nat wash diffserv4 flowblind
    echo "Done. Run 'tc -s qdisc show dev wlan0' and 'tc -s qdisc show dev ifb-wan' to verify."
  '';
in
{
  boot.kernelModules = [ "sch_cake" "ifb" ];

  environment.systemPackages = [ setBandwidth ];

  # IFB (Intermediate Functional Block) device for ingress shaping
  systemd.network.netdevs."05-ifb-wan" = {
    netdevConfig = {
      Kind = "ifb";
      Name = "ifb-wan";
    };
  };

  systemd.network.networks."05-ifb-wan" = {
    matchConfig.Name = "ifb-wan";
    linkConfig.RequiredForOnline = false;
  };

  # Apply CAKE qdisc after the WAN interface comes up
  systemd.services.sqm-cake = {
    description = "Smart Queue Management (CAKE) on WAN";
    after = [ "network-online.target" "sys-subsystem-net-devices-wlan0.device" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    path = [ pkgs.iproute2 pkgs.kmod ];

    # Conservative defaults for a portable router on varying links.
    # Adjust with `set-bandwidth <down> <up>` at runtime.
    script = ''
      # Wait for wlan0 to be up and associated
      for i in $(seq 1 30); do
        if ip link show wlan0 up 2>/dev/null | grep -q "state UP"; then
          break
        fi
        echo "Waiting for wlan0 to come up... ($i/30)"
        sleep 2
      done

      # Bring up IFB device
      ip link set ifb-wan up 2>/dev/null || true

      # Egress shaping on wlan0 (upload from router's perspective)
      tc qdisc replace dev wlan0 root cake bandwidth 20mbit nat wash diffserv4 flowblind
      echo "Applied CAKE egress on wlan0: 20mbit"

      # Ingress shaping via IFB redirect (download from router's perspective)
      tc qdisc replace dev wlan0 handle ffff: ingress 2>/dev/null || tc qdisc add dev wlan0 handle ffff: ingress
      tc filter replace dev wlan0 parent ffff: protocol all u32 match u32 0 0 action mirred egress redirect dev ifb-wan
      tc qdisc replace dev ifb-wan root cake bandwidth 50mbit nat wash diffserv4 flowblind
      echo "Applied CAKE ingress via ifb-wan: 50mbit"
    '';

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };
}
