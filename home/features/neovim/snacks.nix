{ pkgs, ... }:
let
  inherit (import ./lib.nix) snacksKey;
in
{
  programs.nixvim = {
    # snacks only enables modules whose table is present
    plugins.snacks = {
      enable = true;
      settings = {
        bigfile.enabled = true;
        notifier.enabled = true;
        quickfile.enabled = true;
        statuscolumn.enabled = true;
        words.enabled = true;
        indent.enabled = true;
        lazygit.enabled = true;
        picker.enabled = true;
        explorer = {
          enabled = true;
          replace_netrw = true;
        };
      };
    };

    keymaps = [
      # Pickers; grep takes rg args after " -- ", e.g. "foo -- -g=*.nix"
      (snacksKey "<leader>ff" "Snacks.picker.files()" "Find files")
      (snacksKey "<leader>gf" "Snacks.picker.git_files()" "Git files")
      (snacksKey "<leader>fg" "Snacks.picker.grep()" "Grep")
      (snacksKey "<leader>b" "Snacks.picker.buffers()" "Buffers")
      (snacksKey "<leader>fs" "Snacks.picker.treesitter()" "Treesitter symbols")
      (snacksKey "<leader>fr" "Snacks.picker.recent()" "Recent files")
      (snacksKey "<leader>fd" "Snacks.picker.diagnostics()" "Diagnostics")
      (snacksKey "<leader>f." "Snacks.picker.resume()" "Resume last picker")
      (snacksKey "<leader>n" "Snacks.notifier.show_history()" "Notification history")
      (snacksKey "<leader>kb" "Snacks.picker.keymaps()" "Keybind reference")

      (snacksKey "<leader>e" "Snacks.explorer()" "File explorer")
      (snacksKey "<leader>lg" "Snacks.lazygit()" "Lazygit")
    ];

    extraPackages = with pkgs; [ fd lazygit ];
  };
}
