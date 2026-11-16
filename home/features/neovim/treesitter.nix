{ ... }:
{
  programs.nixvim.plugins.treesitter = {
    enable = true;
    highlight.enable = true;
  };

  # Neovim only detects *.jinja; map the other common Jinja extensions too
  programs.nixvim.filetype.extension = {
    j2 = "jinja";
    jinja2 = "jinja";
  };

  # COSMOS plugin.txt.jinja files mix ERB (<% %>) into Jinja; highlight it too
  programs.nixvim.extraFiles."queries/jinja/injections.scm".text = ''
    ;; extends

    ((content) @injection.content
      (#set! injection.language "embedded_template")
      (#set! injection.combined))
  '';
}
