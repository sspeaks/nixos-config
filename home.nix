{ config, pkgs, ... }:

{
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "sspeaks";
  home.homeDirectory = "/home/sspeaks";
  home.packages = with pkgs; [ ripgrep git ];


  programs.neovim = {
      enable = true;
      vimAlias = true;
#      extraConfig = builtins.readFile ./home/extraConfig.vim;

      plugins = with pkgs.vimPlugins; [
        # Syntax / Language Support ##########################
        vim-nix
        #vim-ruby # ruby
        vim-pandoc # pandoc (1/2)
        vim-pandoc-syntax # pandoc (2/2)
        #es.next.syntax.vim # ES7 syntax

        # UI #################################################
        # vim-devicons
        #vim-airline

        # Editor Features ####################################
        #vim-surround # cs"'
        #vim-repeat # cs"'...
        #vim-commentary # gcap
        #vim-ripgrep
        #vim-indent-object # >aI
        #vim-easy-align # vipga
        #vim-eunuch # :Rename foo.rb
        #vim-sneak
        #supertab
        # vim-endwise        # add end, } after opening block
        # gitv
        # tabnine-vim
        #ale # linting
        #nerdtree
        # vim-toggle-quickfix
        # neosnippet.vim
        # neosnippet-snippets
        # splitjoin.vim
        #nerdtree

        # Buffer / Pane / File Management ####################
        #fzf-vim # all the things

        # Panes / Larger features ############################
        #tagbar # <leader>5
        #vim-fugitive # Gblame
      ];
    };

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "21.05";
}
