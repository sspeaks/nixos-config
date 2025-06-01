{ pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;

    shellAliases = {
      ls = "ls --color=auto -F";
      cat = "${pkgs.bat}/bin/bat";
      pbpaste = "wslpath -u $(/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -command '$f=New-TemporaryFile;(Get-Clipboard -Format image).save($f.FullName);echo $f.FullName') |  tr -d '\\r\\n\'";

    };

    initContent = pkgs.lib.mkMerge [
      (pkgs.lib.mkOrder 550 ''
        eval $(${pkgs.coreutils}/bin/dircolors -b)
        ${builtins.readFile ./pre-compinit.zsh}
      '')
      (
        pkgs.lib.mkOrder 1000 (builtins.readFile ./post-compinit.zsh)
      )
    ];

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
}
