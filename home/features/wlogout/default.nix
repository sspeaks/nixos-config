{ config, pkgs, lib, ... }:

let
  # D26 — wlogout re-themed from palette.nix/mocha to plate.nix tokens.
  plate = import ../theme/plate.nix;

  # wlogout (GTK3 + gtk-layer-shell) gains keyboard focus on the layer-shell
  # surface, but never calls gtk_widget_grab_focus() on any child button after
  # gtk_widget_show_all(). GTK3's default window key binding only moves focus
  # to a child on Tab/Shift-Tab, not on arrow keys. When the window opens with
  # no focused widget, arrow key events hit check_key() → return FALSE →
  # GTK's default arrow handler requires a focused child as a starting point
  # → nothing moves → user sees a frozen menu.
  #
  # Fix: inject one call to gtk_widget_child_focus(GTK_DIR_TAB_FORWARD) after
  # gtk_widget_show_all(). This moves focus to the first focusable button in
  # tab order so arrow keys work immediately without any pointer interaction.
  # Confirmed via source inspection of ArtsyMacaw/wlogout@1.2.2 main.c.
  wlogoutPatched = pkgs.wlogout.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace main.c \
        --replace-fail \
          'gtk_widget_show_all(gtk_window);' \
          'gtk_widget_show_all(gtk_window); gtk_widget_child_focus(gtk_window, GTK_DIR_TAB_FORWARD);'
    '';
  });
in
{
  programs.wlogout = {
    enable = true;
    package = wlogoutPatched;
    layout = [
      {
        label = "lock";
        action = "hyprlock";
        text = "Lock";
        keybind = "l";
      }
      {
        label = "logout";
        # D24 wrapper-call swap: the hardcoded `hyprctl dispatch exit` is
        # replaced with the compositor-detection wrapper (Tank's
        # packages/plate-wrappers) so this same button works unmodified
        # under niri. hyprlock (lock, above) is already compositor-agnostic
        # via ext-session-lock-v1 and needs no wrapper.
        action = "plate-logout";
        text = "Logout";
        keybind = "e";
      }
      {
        label = "suspend";
        action = "systemctl suspend";
        text = "Suspend";
        keybind = "u";
      }
      {
        label = "shutdown";
        action = "systemctl poweroff";
        text = "Shutdown";
        keybind = "s";
      }
      {
        label = "reboot";
        action = "systemctl reboot";
        text = "Reboot";
        keybind = "r";
      }
    ];
    style = ''
      * {
        background-image: none;
        font-family: ${plate.type.monoCss};
      }

      window {
        background-color: ${plate.cssRgba plate.bg.void "0.85"};
      }

      button {
        color: ${plate.fg.primary};
        background-color: ${plate.cssRgba plate.bg.panel "0.80"};
        border-style: solid;
        border-width: 2px;
        border-color: ${plate.line.edge};
        background-repeat: no-repeat;
        background-position: center;
        background-size: 25%;
        border-radius: ${plate.geometry.radius};
        margin: 10px;
        transition: all 0.3s ease;
        outline: none;
      }

      /* Focused state: vermilion border + inner glow — must be visually
         distinct from hover so keyboard focus is unambiguous. Placed before
         :hover so specificity ties resolve to :focus when both apply. */
      button:focus {
        background-color: ${plate.cssRgba plate.bg.inset "0.90"};
        border-color: ${plate.state.focus};
        box-shadow: inset 0 0 0 2px ${plate.state.focus};
        outline: none;
      }

      button:hover {
        background-color: ${plate.cssRgba plate.bg.inset "0.90"};
        border-color: ${plate.line.rule};
        outline: none;
      }

      button:active {
        background-color: ${plate.cssRgba plate.bg.panel "0.70"};
        border-color: ${plate.state.focus};
        outline: none;
      }

      #lock {
        background-image: image(url("${wlogoutPatched}/share/wlogout/icons/lock.png"));
      }

      #logout {
        background-image: image(url("${wlogoutPatched}/share/wlogout/icons/logout.png"));
      }

      #suspend {
        background-image: image(url("${wlogoutPatched}/share/wlogout/icons/suspend.png"));
      }

      #shutdown {
        background-image: image(url("${wlogoutPatched}/share/wlogout/icons/shutdown.png"));
      }

      #reboot {
        background-image: image(url("${wlogoutPatched}/share/wlogout/icons/reboot.png"));
      }
    '';
  };
}
