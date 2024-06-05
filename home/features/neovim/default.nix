{ pkgs, inputs, ... }:
let
  telescope_live_args = pkgs.vimUtils.buildVimPlugin {
    name = "telescope-live-grep-args";
    src = pkgs.fetchFromGitHub {
      owner = "nvim-telescope";
      repo = "telescope-live-grep-args.nvim";
      rev = "4122e146d199c0d6d1cfb359c76bc1250d522460";
      sha256 = "sha256-a5IaLd7q9vRJmfiXux7xvXg6vPNouV2+ShdqY/vbHnw=";
    };
  };
in

{
  imports = [ inputs.nixvim.homeManagerModules.nixvim ];

  programs.nixvim = {
    enable = true;
    enableMan = false;
    colorscheme = "desert";
    vimAlias = true;
    extraConfigVim = ''
      set mouse=
    '';

    globals.mapleader = ",";
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
      treesitter.gccPackage = pkgs.gcc;

      lsp = {
        enable = true;
        servers = {
          csharp-ls.enable = true;
          nixd.enable = true;
        };
        keymaps.lspBuf = {
        "gd" = "definition";
        "gD" = "references";
        "gt" = "type_definition";
        "gi" = "implementation";
        "K" = "hover";
      };
      };
      cmp-nvim-lsp.enable = true;
      cmp-buffer.enable = true;
      cmp-path.enable = true;
      cmp.enable = true;
    };
    extraPlugins = with pkgs.vimPlugins; [ ale vim-nix telescope_live_args ];
    extraPackages = with pkgs; [ fd ];
  };
}
