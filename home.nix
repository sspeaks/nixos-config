{ config, pkgs, ... }:

let
  LS_COLORS = pkgs.fetchgit {
    url = "https://github.com/trapd00r/LS_COLORS";
    rev = "6fb72eecdcb533637f5a04ac635aa666b736cf50";
    sha256 = "0czqgizxq7ckmqw9xbjik7i1dfwgc1ci8fvp1fsddb35qrqi857a";
  };
  ls-colors = pkgs.runCommand "ls-colors" { } ''
    mkdir -p $out/bin $out/share
    ln -s ${pkgs.coreutils}/bin/ls $out/bin/ls
    ln -s ${pkgs.coreutils}/bin/dircolors $out/bin/dircolors
    cp ${LS_COLORS}/LS_COLORS $out/share/LS_COLORS
  '';

  #shell-prompt = pkgs.callPackage ./shell-prompt { };
in {
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  fonts.fontconfig.enable = true;

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "sspeaks";
  home.homeDirectory = "/home/sspeaks";
  home.packages = [ pkgs.ripgrep pkgs.git ls-colors 
  #shell-prompt 
  pkgs.starship
  pkgs.pandoc 
  pkgs.htop
  pkgs.shellcheck ];
  home.sessionVariables = {
    EDITOR = "vim";
  };
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      hostname = {
        disabled = true;
      };
      line_break = {
        disabled = true;
      };
      username = {
        format = "[$user]($style) ";
        show_always = true;
      };
      git_branch = {
        format = "[$symbol$branch]($style) ";
      };
    }; 
  };


  programs.git = {
    enable = true;
    userEmail = "sspeaks610@gmail.com";
    userName = "Seth Speaks";
    aliases = {
        fixup = "commit --amend --no-edit --no-verify --allow-empty";
        flog = "log --name-status";
        graph = "!git lg1-specific";
        adog = "log --all --decorate --oneline --graph";
        dog = "log --decorate --oneline --graph";
        lg1 = "!git lg1-specific --all";
        lg2 = "!git lg2-specific --all";
        alias = "config --get-regexp '^alias\\..'";
        ancestor = "show-branch --merge-base";
        lg1-specific = "log --graph --abbrev-commit --decorate --format=format:'%C(auto)%h%C(reset)% C(green)(%ar)%C(reset) - %C(white)%s%C(reset)%C(auto)%d%C(reset)% C(cyan)<%an>%C(reset)'";
        lg2-specific = "log --graph --abbrev-commit --decorate --format=format:'%C(auto)%h%C(reset) - %C(green)%aD%C(reset) %C(dim green)(%ar)%C(reset)%C(dim white)- %an%C(reset)%C(auto)%d%C(reset)%n''          %C(white)%s%C(reset)'";
        current = "log --decorate --stat -1";
        lasthash = "log -1 --pretty=format:'%h'";
    };
  };
  programs.git.lfs.enable = true;

  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
  


  programs.neovim = {
      enable = true;
      vimAlias = true;
      extraConfig = ''
        " Full config: when writing or reading a buffer, and on changes in insert and
        " normal mode (after 500ms; no delay when writing).
"        call neomake#configure#automake('nrwi', 500)
        '';
      plugins = with pkgs.vimPlugins; [
        # Syntax / Language Support ##########################
        ale
        vim-nix
        vim-pandoc # pandoc (1/2)
        vim-pandoc-syntax # pandoc (2/2)
      ];
    };
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      enableAutosuggestions = true;

      shellAliases = {
        ls = "ls --color=auto -F";
      };
      initExtraBeforeCompInit = ''
        eval $(${pkgs.coreutils}/bin/dircolors -b) 
        ${builtins.readFile ./pre-compinit.zsh}
      '';
      initExtra = builtins.readFile ./post-compinit.zsh;

      plugins = [
        {
          name = "zsh-autosuggestions";
          src = pkgs.fetchFromGitHub {
            owner = "zsh-users";
            repo = "zsh-autosuggestions";
            rev = "v0.6.3";
            sha256 = "1h8h2mz9wpjpymgl2p7pc146c1jgb3dggpvzwm9ln3in336wl95c";
          };
        }
        {
          name = "zsh-syntax-highlighting";
          src = pkgs.fetchFromGitHub {
            owner = "zsh-users";
            repo = "zsh-syntax-highlighting";
            rev = "be3882aeb054d01f6667facc31522e82f00b5e94";
            sha256 = "0w8x5ilpwx90s2s2y56vbzq92ircmrf0l5x8hz4g1nx3qzawv6af";
          };
        }
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
