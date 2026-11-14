{ ... }:
let
  inherit (import ./lib.nix) cmdKey;
in
{
  programs.nixvim = {
    plugins.diffview = {
      enable = true;
      settings.view.merge_tool.layout = "diff3_mixed";
    };

    keymaps = [
      (cmdKey "<leader>do" "DiffviewOpen" "Open DiffView")
      (cmdKey "<leader>dc" "DiffviewClose" "Close DiffView")
      (cmdKey "<leader>dh" "DiffviewFileHistory %:p" "Open file history for current open buffer")
      (cmdKey "<leader>dah" "DiffviewFileHistory" "Open all file history")
      (cmdKey "<leader>dm" "DiffviewOpen origin/main...HEAD --imply-local" "Open diff between branch HEAD and main (usual merge base)")
    ];

    # Runs after the colorscheme is applied, so the highlight isn't overwritten
    extraConfigLuaPost = ''
      -- Make diffview less ugly
      vim.opt.fillchars = vim.opt.fillchars + 'diff:╱'
      vim.api.nvim_set_hl(0, 'DiffDelete', { fg = '#444444' })
    '';
  };
}
