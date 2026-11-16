{ ... }:
let
  inherit (import ./lib.nix) cmdKey;
in
{
  # In-buffer markdown rendering; snacks.image (snacks.nix) draws the images, mermaid and math.
  # The cursor's own line shows the raw text for editing; a mermaid block keeps its source
  # as a code block with the diagram below it. For a browser view, <leader>mp opens mdkite.
  programs.nixvim = {
    plugins.render-markdown = {
      enable = true;
      # The default "hide" conceals a code block's closing fence line, and snacks.image hangs
      # a mermaid diagram off that line, so the diagram vanished with it; "thin" keeps it
      settings.code.border = "thin";
    };

    keymaps = [
      (cmdKey "<leader>mr" "RenderMarkdown toggle" "Markdown render")
    ];
  };
}
