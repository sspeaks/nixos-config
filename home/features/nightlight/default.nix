# Declarative Home Manager module for a user-scoped wlsunset service that
# applies night-light / color-temperature changes from sun position.
#
# Asahi limitation: wlsunset uses zwlr_gamma_control_v1, which requires a
# writable KMS gamma LUT in the DRM driver. On Asahi Linux with the apple-dcp
# display driver (kernel 7.1.x), card2-eDP-1 does not expose gamma LUT KMS
# properties, so wlsunset starts, calculates the correct sun trajectory and a
# 4000K night temperature, but logs `gamma control of output eDP-1 (44) failed`
# and produces no visible color shift on the built-in panel. Keep this service
# deployed anyway because an external USB-C/HDMI display may use a driver that
# does support a gamma LUT, and future Asahi kernel updates may add gamma LUT
# support for the built-in display.
#
# Toggle manually with `plate-nightlight-toggle`, which starts/stops the service
# via `systemctl --user`.

{ pkgs, ... }:

{
  home.packages = [ pkgs.wlsunset ];

  systemd.user.services.wlsunset = {
    Unit = {
      Description = "Wayland night light";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wlsunset}/bin/wlsunset -l 37.8 -L -122.4";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
