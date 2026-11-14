{ pkgs, ... }:
let
  plate = import ../theme/plate.nix;
  inherit (plate) bg fg line accent;
in
{
  programs.tmux = {
    enable = true;
    keyMode = "vi";
    prefix = "C-s";
    terminal = "tmux-256color";
    extraConfig = ''
      bind-key h select-pane -L
      bind-key j select-pane -D
      bind-key k select-pane -U
      bind-key l select-pane -R

      bind-key c new-window -c "#{pane_current_path}"
      bind-key '"' split-window -v -c "#{pane_current_path}"
      bind-key % split-window -h -c "#{pane_current_path}"

      # Truecolor + styled underlines from the outer terminal, and let programs
      # (image viewers, scripts/plate-orb.py) pass Kitty graphics through to it.
      set -as terminal-features ",xterm-ghostty:RGB:usstyle:sync:extkeys,xterm-kitty:RGB:usstyle:sync"
      set -g allow-passthrough on

      # Plate status bar: flat void background, text-only segments, no filled blocks
      # (filled blocks render taller than glyphs with Ghostty's adjust-cell-height).
      set -g status-position bottom
      set -g status-justify left
      set -g status-style "bg=${bg.void},fg=${fg.secondary}"
      set -g status-left-length 40
      set -g status-left "#[fg=${accent.vermilion}]▌#[fg=${fg.primary},bold] #S #[default] "
      set -g status-right-length 80
      set -g status-right "#[fg=${fg.muted}]#{b:pane_current_path} #[fg=${line.rule}]│ #[fg=${fg.secondary}]%H:%M "

      set -g window-status-separator ""
      set -g window-status-format "#[fg=${fg.muted}] #I #[fg=${fg.secondary}]#W "
      set -g window-status-current-format "#[fg=${accent.vermilion}] #I #[fg=${fg.primary},bold]#W "
      set -g window-status-activity-style "fg=${accent.vermilion}"
      set -g window-status-bell-style "fg=${accent.vermilion},bold"

      set -g pane-border-style "fg=${line.hairline}"
      set -g pane-active-border-style "fg=${accent.vermilion}"
      set -g pane-border-lines single

      set -g message-style "bg=${bg.panel},fg=${fg.primary}"
      set -g message-command-style "bg=${bg.panel},fg=${fg.primary}"
      set -g mode-style "bg=${line.rule},fg=${fg.primary}"
      set -g clock-mode-colour "${accent.vermilion}"
    '';
  };
}
