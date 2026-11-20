{ ... }:
{
  programs.nixvim.plugins.treesitter = {
    enable = true;
    highlight.enable = true;
  };

  programs.nixvim.plugins.treesitter-textobjects.enable = true;

  # Upstream's main branch has no keymap config; map its move functions directly
  programs.nixvim.keymaps =
    map
      (
        { key, fn, desc }:
        {
          mode = [ "n" "x" "o" ];
          inherit key;
          action.__raw = ''function() require("nvim-treesitter-textobjects.move").${fn}("@function.outer", "textobjects") end'';
          options.desc = desc;
        }
      )
      [
        { key = "]m"; fn = "goto_next_start"; desc = "Next function start"; }
        { key = "[m"; fn = "goto_previous_start"; desc = "Previous function start"; }
        { key = "]M"; fn = "goto_next_end"; desc = "Next function end"; }
        { key = "[M"; fn = "goto_previous_end"; desc = "Previous function end"; }
      ];

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
