{
  tmuxNavigator,
  flakePath,
  hostAttr,
  isDarwin,
  c,
}:
{
  vim = {
    viAlias = true;
    vimAlias = true;
    withNodeJs = true;
    withPython3 = true;
    preventJunkFiles = true;
    undoFile.enable = true;
    lineNumberMode = "relNumber";
    searchCase = "smart";

    options = {
      tabstop = 2;
      shiftwidth = 2;
      expandtab = true;
      autoread = true;
      scrolloff = 8;
    };

    # nvf has no flexoki theme and flexoki-neovim is not in nixpkgs, so the
    # palette is mapped onto base16 by hand.
    theme = {
      enable = true;
      name = "base16";
      base16-colors = {
        base00 = c.bg;
        base01 = c.selection;
        base02 = c.dim;
        base03 = c.gray;
        base04 = c.gray;
        base05 = c.fg;
        base06 = c.fg;
        base07 = c.fg;
        base08 = c.red;
        base09 = c.yellowDeep;
        base0A = c.yellow;
        base0B = c.green;
        base0C = c.cyan;
        base0D = c.blue;
        base0E = c.magenta;
        base0F = c.redDeep;
      };
    };

    lsp = {
      enable = true;

      # The reason nixd is worth the swap: pointed at a real evaluation of this
      # flake, completion and hover cover *our* modules' options, not just
      # upstream NixOS. Home Manager rides in as a NixOS submodule here, so its
      # options have to be unwrapped with getSubOptions rather than read off a
      # homeConfigurations output this flake does not produce.
      servers.nixd.settings.nixd = {
        nixpkgs.expr = ''import (builtins.getFlake "${flakePath}").inputs.nixpkgs { }'';
        # `nixos` is only nixd's name for the slot — on a Mac this is the darwin
        # host, which has the same home-manager submodule underneath.
        options = {
          nixos.expr = ''(builtins.getFlake "${flakePath}").${hostAttr}.options'';
          home_manager.expr = ''(builtins.getFlake "${flakePath}").${hostAttr}.options.home-manager.users.type.getSubOptions [ ]'';
        };
      };
    };
    formatter.conform-nvim.enable = true;
    treesitter.enable = true;
    telescope.enable = true;
    autocomplete.nvim-cmp.enable = true;
    snippets.luasnip.enable = true;
    autopairs.nvim-autopairs.enable = true;
    comments.comment-nvim.enable = true;
    binds.whichKey.enable = true;
    statusline.lualine = {
      enable = true;
      integrations.breadcrumbs.nvim-navic.enable = true;
    };
    filetree.neo-tree.enable = true;
    dashboard.alpha.enable = true;
    terminal.toggleterm.enable = true;
    spellcheck.enable = true;

    git = {
      enable = true;
      gitsigns.enable = true;
    };

    ui = {
      noice.enable = true;
      illuminate.enable = true;
      colorizer.enable = true;
    };

    visuals = {
      nvim-web-devicons.enable = true;
      indent-blankline.enable = true;
      fidget-nvim.enable = true;
      rainbow-delimiters.enable = true;
    };

    utility = {
      surround.enable = true;
      direnv.enable = true;
      oil-nvim.enable = true;
      undotree.enable = true;
      motion.leap.enable = true;
    };

    notes.todo-comments.enable = true;
    mini.hipatterns.enable = true;

    languages = {
      # Per-language lsp.enable defaults to vim.lsp.enable, set above.
      enableTreesitter = true;
      enableFormat = true;

      nix = {
        enable = true;
        # nvf defaults to nil, which only knows upstream NixOS options. nixd can
        # be pointed at a real evaluation, which is the only way completion
        # reaches this flake's own modules — see lsp.servers.nixd below.
        lsp.servers = [ "nixd" ];
        # nvf defaults to alejandra; every file in this repo is nixfmt-formatted,
        # so format-on-save would rewrite the whole tree into the other style.
        format.type = [ "nixfmt" ];
      };
      lua.enable = true;
      python.enable = true;
      typescript.enable = true;
      tsx.enable = true;
      html.enable = true;
      css = {
        # Some Sass speaks plain CSS too, so on Linux it is the only server
        # needed and nvf's css LSP (vscode-css-language-server) is redundant.
        # It stays on darwin, where Some Sass cannot build: nvf builds that
        # server itself and its keytar dependency's node-addon-api does not
        # compile under Apple clang.
        enable = true;
        lsp.enable = isDarwin;
      };
      scss = {
        enable = true;
        lsp.servers = [
          (if isDarwin then "vscode-css-language-server" else "some-sass-language-server")
        ];
      };
      svelte.enable = true;
      vue.enable = true;
      typst.enable = true;
      json.enable = true;
      markdown.enable = true;
      bash.enable = true;
      rust.enable = true;
      tex.enable = true;
    };

    globals = {
      vimtex_view_method = "sioyek";
      vimtex_compiler_method = "latexmk";
      vimtex_compiler_latexmk_engine = "lualatex";
      vimtex_callback_progname = "nvim";
    };

    # No nvf module for this one.
    extraPlugins.vim-tmux-navigator.package = tmuxNavigator;

    # autoread only reloads when Neovim actually checks, hence the polling.
    luaConfigRC.checktime = ''
      vim.api.nvim_create_autocmd(
        { "FocusGained", "BufEnter", "CursorHold", "CursorHoldI", "TermClose", "TermLeave" },
        {
          group = vim.api.nvim_create_augroup("uynx_checktime", { clear = true }),
          callback = function()
            if vim.fn.mode() ~= "c" and vim.bo.buftype == "" then
              vim.cmd.checktime()
            end
          end,
        }
      )

      vim.api.nvim_create_autocmd("FileChangedShellPost", {
        group = vim.api.nvim_create_augroup("uynx_filechanged", { clear = true }),
        callback = function()
          vim.notify("Buffer reloaded from disk", vim.log.levels.INFO)
        end,
      })
    '';

    # Undo files are 0644 and unencrypted; keys.txt is 0600. Never let the
    # private age identity leak into ~/.local/state/nvf/undo.
    luaConfigRC.noUndoForSecrets = ''
      vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
        group = vim.api.nvim_create_augroup("uynx_no_undo_secrets", { clear = true }),
        pattern = "*/.config/sops/*",
        callback = function()
          vim.bo.undofile = false
        end,
      })
    '';
  };
}
