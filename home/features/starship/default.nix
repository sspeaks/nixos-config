{ lib, ... }: {
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      hostname = {
        disabled = lib.mkDefault true;
      };
      line_break = {
        disabled = true;
      };
      username = {
        format = "[$user]($style) ";
        show_always = true;
      };
      git_branch = {
        format = "[$symbol$branch]($style) ";
      };
    };
  };

}
