{ pkgs, ...}:
{
  programs.tmux = {
    enable = true;
    keyMode = "vi";
    prefix = "C-s";
    mouse = true;
    extraConfig = ''
      bind-key h select-pane -L
      bind-key j select-pane -D
      bind-key k select-pane -U
      bind-key l select-pane -R
    '';
    plugins =  with pkgs; [ tmuxPlugins.cpu tmuxPlugins.catppuccin ];
  };
}
