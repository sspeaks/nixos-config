{ pkgs, ... }:
let
  inherit (import ./lib.nix) snacksKey;

  plate = import ../theme/plate.nix;

  # Dark diagrams sit on the editor background instead of mmdr's grey box
  mermaidDark = pkgs.writeText "mermaid-dark.json" (builtins.toJSON {
    themeVariables.background = plate.bg.void;
  });

  # snacks.image always runs `mmdc` with mermaid-cli's flags; route it to the browserless mmdr
  mmdcShim = pkgs.writeShellApplication {
    name = "mmdc";
    runtimeInputs = [ pkgs.mermaid-rs-renderer pkgs.resvg pkgs.imagemagick ];
    text = ''
      src="" out="" theme=dark
      while (( $# )); do
        case $1 in
          -i) src=$2; shift 2 ;;
          -o) out=$2; shift 2 ;;
          -t) theme=$2; shift 2 ;;
          -b|-s) shift 2 ;; # background and scale: mmdr has no equivalent
          *) exec mmdr "$@" ;; # e.g. the version probe from :checkhealth
        esac
      done
      [[ $theme == dark ]] && set -- -c ${mermaidDark}
      # 3x pixels tagged 144 dpi: sharp on HiDPI, shown at ~2x natural size so the text
      # reads at about the editor's own font size. Ghostty drops any image over 10000px
      # on a side, so wide diagrams are scaled down to fit under that.
      mmdr -i "$src" -t "$theme" "$@" | resvg --zoom 3 - "$out" 2>/dev/null
      magick "$out" -resize '9000x9000>' -units Undefined -density 144 "$out"
    '';
  };
in
{
  programs.nixvim = {
    # snacks only enables modules whose table is present
    plugins.snacks = {
      enable = true;
      settings = {
        bigfile.enabled = true;
        notifier.enabled = true;
        quickfile.enabled = true;
        statuscolumn.enabled = true;
        words.enabled = true;
        indent.enabled = true;
        lazygit.enabled = true;
        picker = {
          enabled = true;
          # Typing at the end of the prompt sometimes snaps the cursor back a column, so the
          # next character lands before the last one (folke/snacks.nvim#2810)
          win.input.wo.virtualedit = "all";
        };
        explorer = {
          enabled = true;
          replace_netrw = true;
        };
        # Kitty graphics: images, mermaid and math inline in markdown (tmux passthrough is on)
        image = {
          enabled = true;
          # Default 80x40 cells shrinks tall sequence diagrams until the text is unreadable;
          # the window width still caps them
          doc = {
            max_width = 200;
            max_height = 200;
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

      (snacksKey "<leader>e" "Snacks.explorer()" "File explorer")
      (snacksKey "<leader>lg" "Snacks.lazygit()" "Lazygit")
    ];

    # magick converts non-PNG images, mmdc (mmdr) renders mermaid, tectonic renders math
    extraPackages = with pkgs; [ fd lazygit imagemagick mmdcShim tectonic ];

    # Inside tmux snacks can't see the outer terminal; ask tmux which one is attached
    extraConfigLuaPre = ''
      if vim.env.TMUX and not vim.env.SNACKS_GHOSTTY then
        local term = vim.fn.system({ "tmux", "display-message", "-p", "#{client_termname}" })
        if term:find("ghostty") then
          vim.env.SNACKS_GHOSTTY = "true"
        end
      end
    '';

    # snacks sets this pane's passthrough to "all", which lets a pane in a hidden tmux
    # window keep drawing; "on" limits graphics to visible panes
    extraConfigLua = ''
      if vim.env.TMUX then
        local function visible_only()
          vim.fn.system({ "tmux", "set", "-p", "allow-passthrough", "on" })
        end
        for _, e in ipairs(require("snacks.image.terminal").envs()) do
          if e.name == "tmux" then
            e.setup = visible_only
          end
        end
      end
    '';
  };
}
