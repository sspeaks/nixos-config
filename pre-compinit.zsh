PROMPT='$(shell-prompt "$?" "${__shadowenv_data%%:*}" "${__dev_source_dir}")'
setopt prompt_subst
setopt NO_BEEP
