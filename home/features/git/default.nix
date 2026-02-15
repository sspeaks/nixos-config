{ ... }: {
  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      alias = {
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
      credential = {
        helper = "store";
      };
      core = {
        sshCommand = "ssh -i ~/.ssh/github";
      };
    };
  };

}
