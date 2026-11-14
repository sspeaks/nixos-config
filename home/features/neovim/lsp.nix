{ ... }:
let
  inherit (import ./lib.nix) snacksKey;
in
{
  programs.nixvim = {
    diagnostic.settings = {
      virtual_text = true;
      underline = true;
      signs = true;
    };

    plugins = {
      lsp = {
        enable = true;
        servers = {
          csharp_ls.enable = false;
          nixd.enable = true;
          hls = {
            enable = true;
            package = null; # Use HLS from nix-shell/direnv, not a global one
            installGhc = false; # GHC comes from the project's nix-shell too
            settings = {
              haskell = {
                plugin.semanticTokens.globalOn = true;
              };
            };
          };
          pylsp.enable = false;
          # Rust is handled by rustaceanvim below; enabling both attaches two clients
        };
        # gd/gD/gt/gi go through snacks pickers, see keymaps below
        keymaps.lspBuf = {
          "K" = "hover";
          "ga" = "code_action";
        };
      };
      # Drives rust-analyzer itself; cargo/rustc come from the project's dev shell
      rustaceanvim.enable = true;
    };

    keymaps = [
      (snacksKey "gd" "Snacks.picker.lsp_definitions()" "Goto definition")
      (snacksKey "gD" "Snacks.picker.lsp_references()" "References")
      (snacksKey "gt" "Snacks.picker.lsp_type_definitions()" "Goto type definition")
      (snacksKey "gi" "Snacks.picker.lsp_implementations()" "Goto implementation")
      (snacksKey "]]" "Snacks.words.jump(vim.v.count1)" "Next reference")
      (snacksKey "[[" "Snacks.words.jump(-vim.v.count1)" "Previous reference")
    ];
  };
}
