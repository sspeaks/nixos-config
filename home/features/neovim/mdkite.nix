{ pkgs, ... }:
let
  inherit (import ./lib.nix) cmdKey;

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
in
{
  programs.nixvim = {
    extraPlugins = [ mdkite-nvim ];

    extraConfigLua = ''
      require("mdkite").setup({ default_theme = "dark" })
    '';

    keymaps = [
      (cmdKey "<leader>mp" "MdKite toggle" "Markdown preview")
    ];
  };
}
