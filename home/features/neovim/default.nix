{ pkgs, inputs, ... }:
let
  # Not packaged in nixpkgs; mdkite needs kitehost >= 2.0.0
  kitehost-nvim = pkgs.vimUtils.buildVimPlugin {
    pname = "kitehost.nvim";
    version = "2.0.0";
    src = pkgs.fetchFromGitHub {
      owner = "selimacerbas";
      repo = "kitehost.nvim";
      rev = "v2.0.0";
      hash = "sha256-XHbCbooxN+29qCQT9XasihZFdYonDaWufFUSNowNdnk=";
    };
  };
  mdkite-nvim = pkgs.vimUtils.buildVimPlugin {
    pname = "mdkite.nvim";
    version = "2.1.0";
    src = pkgs.fetchFromGitHub {
      owner = "selimacerbas";
      repo = "mdkite.nvim";
      rev = "v2.1.0";
      hash = "sha256-V3NRsP7ZGR+6p5wC/lS1nebnPsLevLgT4HWcDO1TKyo=";
    };
    dependencies = [ kitehost-nvim ];
  };

  # snacks centers each header line on its own, so pad them to one width
  padLines = text:
    let
      lines = pkgs.lib.splitString "\n" text;
      width = pkgs.lib.foldl' (acc: l: pkgs.lib.max acc (builtins.stringLength l)) 0 lines;
    in
    pkgs.lib.concatMapStringsSep "\n"
      (l: l + pkgs.lib.strings.replicate (width - builtins.stringLength l) " ")
      lines;

  snacksKey = key: fn: desc: {
    mode = "n";
    inherit key;
    action.__raw = "function() ${fn} end";
    options.desc = desc;
  };
  cmdKey = key: cmd: desc: {
    mode = "n";
    inherit key;
    action = "<cmd>${cmd}<cr>";
    options.desc = desc;
  };
in
{
  imports = [ inputs.nixvim.homeModules.nixvim ];

  programs.nixvim = {
    enable = true;
    enableMan = false;
    vimAlias = true;
    nixpkgs.useGlobalPackages = true;
    version.enableNixpkgsReleaseCheck = false;
    extraConfigVim = ''
      set mouse=
      let g:ale_linters = {'haskell': []}
    '';

    diagnostic.settings = {
      virtual_text = true;
      underline = true;
      signs = true;
    };

    colorschemes.catppuccin = {
      enable = true;
      settings.flavour = "mocha";
    };

    globals.mapleader = ",";

    dependencies = {
      gcc = {
        enable = true;
        package = pkgs.gcc;
      };
    };

    plugins = {
      # snacks only enables modules whose table is present
      snacks = {
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
          dashboard = {
            enabled = true;
            # no '' pairs in the art: they would end the Nix string
            preset.header = padLines ''
                                   /\
                       *          /  \          .
                                 /    \     +
                    .           |      |
                                |  ()  |            *
                       +        |      |       .
                                |  ()  |
                     .         /|      |\          .
                              / |      | \     *
                             /__|______|__\
                                \/\/\/\/        +
                         *       \/\/\/
                                  \/\/         .
                        .          \/

                       ground control to major vim'';
            preset.keys = [
              { icon = " "; key = "f"; desc = "Find File"; action.__raw = "function() Snacks.picker.files() end"; }
              { icon = " "; key = "g"; desc = "Grep"; action.__raw = "function() Snacks.picker.grep() end"; }
              { icon = " "; key = "r"; desc = "Recent Files"; action.__raw = "function() Snacks.picker.recent() end"; }
              { icon = " "; key = "e"; desc = "Explorer"; action.__raw = "function() Snacks.explorer() end"; }
              { icon = " "; key = "l"; desc = "Lazygit"; action.__raw = "function() Snacks.lazygit() end"; }
              { icon = " "; key = "q"; desc = "Quit"; action = ":qa"; }
            ];
            # The default "startup" section requires lazy.nvim
            sections = [
              { section = "header"; }
              { section = "keys"; gap = 1; padding = 1; }
            ];
          };
        };
      };

      diffview = {
        enable = true;
        settings = {
          enhanced_diff_hl = true;
          view.merge_tool.layout = "diff3_mixed";
        };
      };

      treesitter.enable = true;

      web-devicons.enable = true;

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
        };
        # gd/gD/gt/gi go through snacks pickers, see keymaps below
        keymaps.lspBuf = {
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

      # LSP
      (snacksKey "gd" "Snacks.picker.lsp_definitions()" "Goto definition")
      (snacksKey "gD" "Snacks.picker.lsp_references()" "References")
      (snacksKey "gt" "Snacks.picker.lsp_type_definitions()" "Goto type definition")
      (snacksKey "gi" "Snacks.picker.lsp_implementations()" "Goto implementation")
      (snacksKey "]]" "Snacks.words.jump(vim.v.count1)" "Next reference")
      (snacksKey "[[" "Snacks.words.jump(-vim.v.count1)" "Previous reference")

      (snacksKey "<leader>e" "Snacks.explorer()" "File explorer")
      (snacksKey "<leader>lg" "Snacks.lazygit()" "Lazygit")

      # Diffview
      (cmdKey "<leader>gd" "DiffviewOpen" "Diffview: working tree")
      (cmdKey "<leader>gh" "DiffviewFileHistory %" "Diffview: file history")
      (cmdKey "<leader>gH" "DiffviewFileHistory" "Diffview: repo history")
      (cmdKey "<leader>gq" "DiffviewClose" "Diffview: close")

      (cmdKey "<leader>mp" "MdKite toggle" "Markdown preview")
    ];

    extraConfigLua = ''
      require("mdkite").setup({ default_theme = "dark" })
    '';

    extraPlugins = with pkgs.vimPlugins; [ ale vim-nix mdkite-nvim ];
    extraPackages = with pkgs; [ fd lazygit ];
  };
}
