# Keymap helpers shared by the neovim modules; not a module itself
{
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
}
