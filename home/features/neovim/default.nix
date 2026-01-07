{ pkgs, inputs, ... }:
# let
#   telescope_live_args = pkgs.vimUtils.buildVimPlugin {
#     name = "telescope-live-grep-args";
#     src = pkgs.fetchFromGitHub {
#       owner = "nvim-telescope";
#       repo = "telescope-live-grep-args.nvim";
#       rev = "b80ec2c70ec4f32571478b501218c8979fab5201";
#       sha256 = "sha256-VmX7K21v3lErm7f5I7/1rJ/+fSbFxZPrbDokra9lZpQ=";
#     };
#   };
# in

{
  imports = [ inputs.nixvim.homeManagerModules.nixvim ];

  programs.nixvim = {
    enable = true;
    enableMan = false;
    vimAlias = true;
    extraConfigVim = ''
      set mouse=
    '';

    globals.mapleader = ",";

    dependencies = {
      gcc = {
        enable = true;
        package = pkgs.gcc;
      };
    };

    plugins = {
      telescope = {
        enable = true;
        keymaps = {
          "<leader>ff" = "find_files";
          "<leader>gf" = "git_files";
          "<leader>fg" = "live_grep_args";
          "<leader>b" = "buffers";
          "<leader>fs" = "treesitter";
        };
        enabledExtensions = [ "live_grep_args" ];

      };
      treesitter.enable = true;

      web-devicons.enable = true;

      lsp = {
        enable = true;
        servers = {
          csharp_ls.enable = false;
          nixd.enable = true;
          hls.enable = false;
          pylsp.enable = false;
        };
        keymaps.lspBuf = {
          "gd" = "definition";
          "gD" = "references";
          "gt" = "type_definition";
          "gi" = "implementation";
          "K" = "hover";
          "ga" = "code_action";
        };
      };
      luasnip.enable = true;
      comment.enable = true;
      cmp-nvim-lsp.enable = true;
      cmp-buffer.enable = true;
      cmp-path.enable = true;
      cmp = {
        enable = true;
        settings = {
          sources = [
            { name = "nvim_lsp"; }
            { name = "luasnip"; }
            { name = "buffer"; }
            { name = "path"; }
          ];
          mapping = {
            "<C-n>" = "cmp.mapping.select_next_item()";
            "<C-p>" = "cmp.mapping.select_prev_item()";
            "<C-u>" = "cmp.mapping.scroll_docs(-4)";
            "<C-d>" = "cmp.mapping.scroll_docs(4)";
            "<C-Space>" = "cmp.mapping.complete()";
            "<C-e>" = "cmp.mapping.abort()";
            "<CR>" = "cmp.mapping.confirm({ select = true })";
          };
          snippet = {
            expand = "function(args) require('luasnip').lsp_expand(args.body) end";
          };
        };
      };
    };
    extraPlugins = with pkgs.vimPlugins; [ ale vim-nix telescope-live-grep-args-nvim ];
    extraPackages = with pkgs; [ fd ];
  };
}
