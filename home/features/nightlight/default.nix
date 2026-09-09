# wlsunset requires zwlr_gamma_control_v1 and a writable DRM gamma LUT.
# On apple-dcp with kernel 7.1.x, the built-in panel lacks a gamma LUT; keep
# the service for displays/drivers that support it.
# Toggle with plate-nightlight-toggle.

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
