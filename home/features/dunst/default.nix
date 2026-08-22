{ ... }:

let
  # D26 — dunst re-themed from palette.nix/mocha to plate.nix tokens.
  # dunst stays wired for the Hyprland session (D23); it is not replaced,
  # only re-skinned, so both sessions look consistent while both exist.
  plate = import ../theme/plate.nix;
in
{
  services.dunst = {
    enable = true;
    settings = {
      global = {
        # Display
        monitor = 0;
        follow = "mouse";

        # Geometry
        width = 300;
        height = 300;
        origin = "top-right";
        offset = "10x50";
        scale = 0;

        # Progress bar
        progress_bar = true;
        progress_bar_height = 10;
        progress_bar_frame_width = 1;
        progress_bar_corner_radius = 5;
        progress_bar_min_width = 150;
        progress_bar_max_width = 300;

        # Notifications
        indicate_hidden = true;
        shrink = false;
        transparency = 10;
        notification_limit = 5;
        separator_height = 2;
        padding = 8;
        horizontal_padding = 8;
        text_icon_padding = 0;
        frame_width = 2;
        frame_color = plate.line.edge;
        gap_size = 5;
        separator_color = "frame";
        sort = true;

        # Text
        font = "${plate.type.mono} 10";
        line_height = 0;
        markup = "full";
        format = "<b>%s</b>\\n%b";
        alignment = "left";
        vertical_alignment = "center";
        show_age_threshold = 60;
        ellipsize = "middle";
        ignore_newline = false;
        stack_duplicates = true;
        hide_duplicate_count = false;
        show_indicators = true;

        # Icons
        icon_position = "left";
        min_icon_size = 32;
        max_icon_size = 64;

        # History
        sticky_history = true;
        history_length = 20;

        # Misc
        browser = "xdg-open";
        always_run_script = true;
        title = "Dunst";
        class = "Dunst";
        # UNRESOLVED (D26/D29 #4): Plate XIV geometry is radius "0px" everywhere
        # else, but dunst's corner_radius/progress_bar_corner_radius are left
        # as their pre-existing non-token literals (10 / 5) rather than forced
        # to 0. This may be a deliberate exception or an oversight — Seth has
        # not decided (see D29 #4) — so behavior is preserved unchanged here
        # rather than making an irreversible aesthetic call on his behalf.
        corner_radius = 10;
        ignore_dbusclose = false;

        # Mouse actions
        mouse_left_click = "close_current";
        mouse_middle_click = "do_action, close_current";
        mouse_right_click = "close_all";
      };

      urgency_low = {
        background = plate.bg.panel;
        foreground = plate.fg.primary;
        frame_color = plate.line.rule;
        timeout = 5;
      };

      urgency_normal = {
        background = plate.bg.panel;
        foreground = plate.fg.primary;
        frame_color = plate.line.edge;
        timeout = 10;
      };

      urgency_critical = {
        background = plate.bg.panel;
        foreground = plate.fg.primary;
        # D25 — failure/error token (= vermilion, no new hue).
        frame_color = plate.state.fail;
        timeout = 0;
      };
    };
  };

  # D23 gating fix (review follow-up): dunst stays enabled for the Hyprland
  # rollback session, but must not also start under niri where Quickshell's
  # NotificationHost owns notifications — two daemons racing for
  # org.freedesktop.Notifications would silently produce a duplicate/lost
  # notification surface. home-manager's dunst module (services/dunst.nix)
  # wires `systemd.user.services.dunst` with `PartOf`/`After` on
  # `config.wayland.systemd.target`, which is reached by *both* Hyprland's
  # and niri's own systemd integration — no compositor scoping exists
  # upstream. This adds a `ConditionEnvironment` gate using the existing,
  # standard systemd HM pattern of extending an already-defined
  # `systemd.user.services.<name>` unit (module-system attrset merge, no
  # override of home-manager's own Unit/Service keys).
  #
  # Gated on `$NIRI_SOCKET` rather than `$XDG_CURRENT_DESKTOP` because the
  # exact XDG_CURRENT_DESKTOP string niri's systemd integration exports is
  # not independently confirmed for this nixpkgs niri build, and D24 already
  # forbids guessing strings. `NIRI_SOCKET` is not a guess: `strings` on the
  # installed niri 26.04 binary shows it runs its own internal
  # `systemctl --user import-environment ...` call whose imported-variable
  # list literally includes `NIRI_SOCKET` (alongside WAYLAND_DISPLAY,
  # XDG_CURRENT_DESKTOP) — so this variable is genuinely present in the
  # systemd --user manager's environment block for the lifetime of a niri
  # session, which is exactly what `ConditionEnvironment=` inspects (per
  # systemd.unit(5): it checks the service manager's own environment block,
  # not the shell's). Under Hyprland, `$NIRI_SOCKET` is never set, so the
  # condition passes and dunst starts normally — same wrapper-script
  # detection signal Tank's packages/plate-wrappers already relies on.
  #
  # Explicit failure/skip behavior, no silent guess: if the condition is not
  # met, systemd marks the unit "skipped" (not failed, not started) — dunst
  # simply never launches under niri, and Quickshell's NotificationServer
  # (which is not `PartOf`/gated on anything, and has no D-Bus name
  # contention if dunst never starts) is the sole notification daemon there.
  systemd.user.services.dunst.Unit.ConditionEnvironment = "!NIRI_SOCKET";
}
