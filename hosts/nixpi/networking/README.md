# nixpi travel router

`nixpi` is the travel-router configuration for the same Pi 4 that also has the
`nixpi4-bare` configuration. Only one can be deployed at a time.

## Network roles

| Role | Interface | Configuration |
| --- | --- | --- |
| Upstream Wi-Fi | `wlan0` | Joins configured networks and obtains an IPv4 address with DHCP. A phone hotspot needs matching configured credentials. |
| Trusted LAN | `br-lan` | Bridges Ethernet `end0` and the Wi-Fi access point; router address is `192.168.10.1/24`. |
| Wi-Fi access point | `wlp1s0u2` | hostapd on 5 GHz channel 44, with SOPS-backed credentials. |

dnsmasq serves LAN addresses from `192.168.10.50` through `192.168.10.254` and
resolves `nixpi.lan`. Connect over Ethernet or the access point for SSH; new SSH
connections arriving through upstream `wlan0` are blocked.

**WireGuard is disabled and has no configured endpoint.** A phone hotspot
provides upstream connectivity, not an active VPN or remote-SSH fallback.
Internet traffic currently uses direct WLAN forwarding/NAT.

## Access-point troubleshooting

Inspect startup failures with `journalctl -u hostapd -f`. If the logs indicate a
channel problem, use `iw list` to check the AP adapter's supported channels and
compare them with `hostapd.nix`; do not assume both Wi-Fi adapters support the
same channels.
