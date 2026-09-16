{ config, lib, pkgs, ... }:

let
  taskrc = "${config.xdg.configHome}/task/taskrc";
  opener =
    if pkgs.stdenv.hostPlatform.isDarwin
    then "/usr/bin/open"
    else "${pkgs.xdg-utils}/bin/xdg-open";
  taskopenSettings = {
    General = {
      taskbin = lib.getExe config.programs.taskwarrior.package;
      EDITOR = "${config.programs.nixvim.build.package}/bin/nvim";
      no_annotation_hook = "";
    };
    Actions = {
      "files.regex" = "^[./~].*";
      "files.command" = lib.concatStringsSep " " [
        ''case "$FILE" in''
        ''*.md|*.markdown|*.txt|*.wiki) exec "$EDITOR" "$FILE" ;;''
        ''*) exec ${opener} "$FILE" ;;''
        "esac"
      ];
      "notes.regex" = "^Notes$";
      "notes.command" = lib.concatStringsSep " " [
        ''${pkgs.coreutils}/bin/mkdir -p "$HOME/vimwiki/tasknotes" &&''
        ''exec "$EDITOR" "$HOME/vimwiki/tasknotes/$UUID.md"''
      ];
      "url.regex" = "^(https?://|www\\.).*";
      "url.command" = lib.concatStringsSep " " [
        ''if [ -n "''${BROWSER:-}" ]; then''
        ''exec "$BROWSER" "$FILE";''
        "else"
        ''exec ${opener} "$FILE";''
        "fi"
      ];
    };
  };
in
{
  programs.taskwarrior = {
    enable = true;
    package = pkgs.taskwarrior3;
  };

  home.packages = [ pkgs.taskopen ];
  home.sessionVariables.TASKRC = taskrc;

  programs.nixvim = {
    withPython3 = true;
    extraPython3Packages = ps: [ ps.tasklib ps.packaging ];
    extraPackages = [ config.programs.taskwarrior.package ];
    extraPlugins = [ pkgs.vimPlugins.taskwiki ];

    globals = {
      taskwiki_taskrc_location = taskrc;
      taskwiki_data_location = config.programs.taskwarrior.dataLocation;
    };

    plugins.vimwiki = {
      enable = true;
      settings = {
        global_ext = 0;
        markdown_link_ext = 1;
        list = [{
          path = "~/vimwiki/";
          syntax = "markdown";
          ext = ".md";
        }];
      };
    };
  };

  # Taskopen's INI parser needs quoted strings, including escaped regexes.
  xdg.configFile."taskopen/taskopenrc".text = lib.generators.toINI
    { mkKeyValue = key: value: "${key} = ${builtins.toJSON value}"; }
    taskopenSettings;
}
