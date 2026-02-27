{ pkgs, ... }:
let
  # API script that generates JSON status data
  statusApi = pkgs.writeShellScript "router-status-api" ''
    export PATH="${pkgs.lib.makeBinPath [
      pkgs.iproute2 pkgs.iw pkgs.coreutils pkgs.gawk
      pkgs.gnugrep pkgs.gnused pkgs.jq pkgs.hostapd
      pkgs.procps pkgs.vnstat
    ]}"

    echo "Content-Type: application/json"
    echo ""

    # WAN info
    wan_ip=$(ip -4 addr show wlan0 2>/dev/null | grep -oP 'inet \K[0-9.]+' | head -1)
    wan_gw=$(ip route show default dev wlan0 2>/dev/null | awk '{print $3}' | head -1)
    wan_state=$(ip link show wlan0 2>/dev/null | grep -oP 'state \K\w+')

    # WiFi signal on WAN uplink
    signal=$(iw dev wlan0 link 2>/dev/null | grep signal | awk '{print $2}')
    ssid=$(iw dev wlan0 link 2>/dev/null | grep SSID | sed 's/.*SSID: //')

    # hostapd AP info
    ap_channel=$(iw dev wlp1s0u2 info 2>/dev/null | grep channel | head -1 | awk '{print $2}')
    ap_freq=$(iw dev wlp1s0u2 info 2>/dev/null | grep channel | head -1 | sed 's/.*(\([0-9]*\) MHz).*/\1/')

    # Connected stations
    stations=$(hostapd_cli -i wlp1s0u2 all_sta 2>/dev/null | grep -c "^[0-9a-f]" || echo "0")

    # DHCP leases
    leases="[]"
    if [ -f /var/lib/dnsmasq/dnsmasq.leases ]; then
      leases=$(awk '{printf "{\"mac\":\"%s\",\"ip\":\"%s\",\"host\":\"%s\"},", $2, $3, $4}' /var/lib/dnsmasq/dnsmasq.leases | sed 's/,$//' | sed 's/^/[/' | sed 's/$/]/')
      [ -z "$leases" ] || [ "$leases" = "[]" ] || true
    fi
    [ -z "$leases" ] && leases="[]"

    # Uptime
    uptime=$(uptime -p 2>/dev/null || echo "unknown")

    # Memory
    mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    mem_avail=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)

    # CPU temp
    cpu_temp="N/A"
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
      raw=$(cat /sys/class/thermal/thermal_zone0/temp)
      cpu_temp="$(echo "scale=1; $raw / 1000" | ${pkgs.bc}/bin/bc)°C"
    fi

    # vnStat traffic summary
    vnstat_json=$(vnstat --json s 2>/dev/null || echo '{}')

    # SQM status
    sqm_egress=$(tc -s qdisc show dev wlan0 2>/dev/null | head -1 || echo "none")
    sqm_ingress=$(tc -s qdisc show dev ifb-wan 2>/dev/null | head -1 || echo "none")

    jq -n \
      --arg wan_ip "''${wan_ip:-disconnected}" \
      --arg wan_gw "''${wan_gw:-none}" \
      --arg wan_state "''${wan_state:-UNKNOWN}" \
      --arg signal "''${signal:-N/A}" \
      --arg ssid "''${ssid:-N/A}" \
      --arg ap_channel "''${ap_channel:-N/A}" \
      --arg ap_freq "''${ap_freq:-N/A}" \
      --arg stations "$stations" \
      --argjson leases "$leases" \
      --arg uptime "$uptime" \
      --arg mem_total "$mem_total" \
      --arg mem_avail "$mem_avail" \
      --arg cpu_temp "$cpu_temp" \
      --arg sqm_egress "$sqm_egress" \
      --arg sqm_ingress "$sqm_ingress" \
      '{
        wan: { ip: $wan_ip, gateway: $wan_gw, state: $wan_state, signal_dbm: $signal, ssid: $ssid },
        ap: { channel: $ap_channel, frequency_mhz: $ap_freq, connected_stations: $stations },
        clients: $leases,
        system: { uptime: $uptime, mem_total_kb: $mem_total, mem_available_kb: $mem_avail, cpu_temp: $cpu_temp },
        sqm: { egress: $sqm_egress, ingress: $sqm_ingress }
      }'
  '';

  dashboardHtml = pkgs.writeText "index.html" ''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>nixpi Router Dashboard</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, monospace;
               background: #0d1117; color: #c9d1d9; padding: 16px; }
        h1 { color: #58a6ff; margin-bottom: 16px; font-size: 1.4em; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 12px; }
        .card { background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 16px; }
        .card h2 { color: #8b949e; font-size: 0.85em; text-transform: uppercase; letter-spacing: 1px;
                    margin-bottom: 10px; }
        .stat { display: flex; justify-content: space-between; padding: 4px 0; border-bottom: 1px solid #21262d; }
        .stat:last-child { border-bottom: none; }
        .label { color: #8b949e; }
        .value { color: #f0f6fc; font-weight: 500; }
        .value.good { color: #3fb950; }
        .value.warn { color: #d29922; }
        .value.bad { color: #f85149; }
        table { width: 100%; border-collapse: collapse; }
        th { text-align: left; color: #8b949e; font-size: 0.8em; padding: 4px 8px;
             border-bottom: 1px solid #30363d; }
        td { padding: 4px 8px; border-bottom: 1px solid #21262d; font-size: 0.9em; }
        .refresh { color: #8b949e; font-size: 0.75em; margin-top: 12px; text-align: center; }
        #error { display: none; background: #f8514922; border: 1px solid #f85149; border-radius: 4px;
                 padding: 8px; margin-bottom: 12px; color: #f85149; }
      </style>
    </head>
    <body>
      <h1>&#x1F4E1; nixpi Router</h1>
      <div id="error"></div>
      <div class="grid">
        <div class="card">
          <h2>&#x1F310; WAN Uplink</h2>
          <div class="stat"><span class="label">State</span><span class="value" id="wan-state">-</span></div>
          <div class="stat"><span class="label">SSID</span><span class="value" id="wan-ssid">-</span></div>
          <div class="stat"><span class="label">IP</span><span class="value" id="wan-ip">-</span></div>
          <div class="stat"><span class="label">Gateway</span><span class="value" id="wan-gw">-</span></div>
          <div class="stat"><span class="label">Signal</span><span class="value" id="wan-signal">-</span></div>
        </div>
        <div class="card">
          <h2>&#x1F4F6; Access Point</h2>
          <div class="stat"><span class="label">Channel</span><span class="value" id="ap-channel">-</span></div>
          <div class="stat"><span class="label">Frequency</span><span class="value" id="ap-freq">-</span></div>
          <div class="stat"><span class="label">Stations</span><span class="value" id="ap-stations">-</span></div>
        </div>
        <div class="card">
          <h2>&#x1F4BB; System</h2>
          <div class="stat"><span class="label">Uptime</span><span class="value" id="sys-uptime">-</span></div>
          <div class="stat"><span class="label">CPU Temp</span><span class="value" id="sys-temp">-</span></div>
          <div class="stat"><span class="label">Memory</span><span class="value" id="sys-mem">-</span></div>
        </div>
        <div class="card">
          <h2>&#x1F6E1;&#xFE0F; SQM / Traffic Shaping</h2>
          <div class="stat"><span class="label">Egress</span><span class="value" id="sqm-eg">-</span></div>
          <div class="stat"><span class="label">Ingress</span><span class="value" id="sqm-in">-</span></div>
        </div>
        <div class="card" style="grid-column: 1 / -1;">
          <h2>&#x1F465; Connected Clients</h2>
          <table>
            <thead><tr><th>Hostname</th><th>IP Address</th><th>MAC Address</th></tr></thead>
            <tbody id="clients"><tr><td colspan="3">Loading...</td></tr></tbody>
          </table>
        </div>
      </div>
      <div class="refresh">Auto-refreshes every 5 seconds | <span id="last-update">-</span></div>
      <script>
        function signalClass(dbm) {
          const n = parseInt(dbm);
          if (isNaN(n)) return "";
          if (n >= -50) return "good";
          if (n >= -70) return "warn";
          return "bad";
        }
        function stateClass(s) {
          return s === "UP" ? "good" : "bad";
        }
        async function refresh() {
          try {
            const r = await fetch("/api/status");
            if (!r.ok) throw new Error("HTTP " + r.status);
            const d = await r.json();
            document.getElementById("error").style.display = "none";

            const w = d.wan;
            document.getElementById("wan-state").textContent = w.state;
            document.getElementById("wan-state").className = "value " + stateClass(w.state);
            document.getElementById("wan-ssid").textContent = w.ssid;
            document.getElementById("wan-ip").textContent = w.ip;
            document.getElementById("wan-gw").textContent = w.gateway;
            document.getElementById("wan-signal").textContent = w.signal_dbm + " dBm";
            document.getElementById("wan-signal").className = "value " + signalClass(w.signal_dbm);

            document.getElementById("ap-channel").textContent = d.ap.channel;
            document.getElementById("ap-freq").textContent = d.ap.frequency_mhz + " MHz";
            document.getElementById("ap-stations").textContent = d.ap.connected_stations;

            document.getElementById("sys-uptime").textContent = d.system.uptime;
            document.getElementById("sys-temp").textContent = d.system.cpu_temp;
            const memPct = Math.round((1 - d.system.mem_available_kb / d.system.mem_total_kb) * 100);
            document.getElementById("sys-mem").textContent = memPct + "% used";
            document.getElementById("sys-mem").className = "value " + (memPct > 90 ? "bad" : memPct > 70 ? "warn" : "good");

            document.getElementById("sqm-eg").textContent = d.sqm.egress;
            document.getElementById("sqm-in").textContent = d.sqm.ingress;

            const tbody = document.getElementById("clients");
            if (d.clients.length === 0) {
              tbody.innerHTML = '<tr><td colspan="3" style="color:#8b949e">No clients connected</td></tr>';
            } else {
              tbody.innerHTML = d.clients.map(c =>
                '<tr><td>' + (c.host || '*') + '</td><td>' + c.ip + '</td><td style="color:#8b949e">' + c.mac + '</td></tr>'
              ).join("");
            }
            document.getElementById("last-update").textContent = new Date().toLocaleTimeString();
          } catch(e) {
            document.getElementById("error").style.display = "block";
            document.getElementById("error").textContent = "Failed to fetch status: " + e.message;
          }
        }
        refresh();
        setInterval(refresh, 5000);
      </script>
    </body>
    </html>
  '';

  # Minimal CGI wrapper for nginx
  statusCgi = pkgs.writeShellScript "status-cgi" ''
    exec ${statusApi}
  '';
in
{
  services.vnstat.enable = true;

  # nginx serving the dashboard on the LAN only
  services.nginx = {
    enable = true;
    virtualHosts."router-dashboard" = {
      listen = [{ addr = "192.168.10.1"; port = 8080; }];
      root = pkgs.runCommand "dashboard-root" { } ''
        mkdir -p $out
        cp ${dashboardHtml} $out/index.html
      '';
      locations."/api/status" = {
        extraConfig = ''
          fastcgi_pass unix:/run/fcgiwrap-router-status.sock;
          include ${pkgs.nginx}/conf/fastcgi_params;
          fastcgi_param SCRIPT_FILENAME ${statusCgi};
        '';
      };
    };
  };

  services.fcgiwrap.instances.router-status = {
    process.user = "root";
    process.group = "nginx";
    socket.type = "unix";
    socket.address = "/run/fcgiwrap-router-status.sock";
    socket.user = "root";
    socket.group = "nginx";
    socket.mode = "0660";
  };
}
