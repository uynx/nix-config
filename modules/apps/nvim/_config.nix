{
  tmuxNavigator,
  vimtex,
  nvim-treesitter-textobjects,
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

      servers.nixd.settings.nixd = {
        nixpkgs.expr = ''import (builtins.getFlake "${flakePath}").inputs.nixpkgs { }'';
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
      grug-far-nvim.enable = true;
      motion.leap = {
        enable = true;
        mappings = {
          leapForwardTo = "s";
          leapBackwardTo = "S";
        };
      };
    };

    notes.todo-comments.enable = true;
    mini = {
      hipatterns.enable = true;
      ai.enable = true;
    };

    languages = {
      enableTreesitter = true;
      enableFormat = true;
      enableExtraDiagnostics = true;

      nix = {
        enable = true;
        lsp.servers = [ "nixd" ];
        format.type = [ "nixfmt" ];
      };
      lua.enable = true;
      python.enable = true;
      typescript.enable = true;
      tsx.enable = true;
      html.enable = true;
      css = {
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
      vimtex_callback_progpath = "nvim";
      vimtex_compiler_latexmk_engines._ = "-lualatex";
      vimtex_compiler_latexmk = {
        aux_dir = "build";
        options = [
          "-shell-escape"
          "-verbose"
          "-file-line-error"
          "-synctex=1"
          "-interaction=nonstopmode"
        ];
      };
    };

    extraPlugins = {
      vim-tmux-navigator.package = tmuxNavigator;
      vimtex.package = vimtex;

      nvim-treesitter-textobjects = {
        package = nvim-treesitter-textobjects;
        setup = ''
          require("nvim-treesitter-textobjects").setup({ select = { lookahead = true } })

          local select = require("nvim-treesitter-textobjects.select")
          for lhs, query in pairs({
            am = "@function.outer",
            im = "@function.inner",
            ac = "@class.outer",
            ic = "@class.inner",
            al = "@loop.outer",
            il = "@loop.inner",
            ak = "@conditional.outer",
            ik = "@conditional.inner",
          }) do
            vim.keymap.set({ "x", "o" }, lhs, function()
              select.select_textobject(query, "textobjects")
            end, { desc = "Select " .. query })
          end

          local move = require("nvim-treesitter-textobjects.move")
          for lhs, query in pairs({ ["]m"] = "@function.outer", ["]]"] = "@class.outer" }) do
            vim.keymap.set({ "n", "x", "o" }, lhs, function()
              move.goto_next_start(query, "textobjects")
            end, { desc = "Next " .. query })
          end
          for lhs, query in pairs({ ["[m"] = "@function.outer", ["[["] = "@class.outer" }) do
            vim.keymap.set({ "n", "x", "o" }, lhs, function()
              move.goto_previous_start(query, "textobjects")
            end, { desc = "Previous " .. query })
          end
        '';
      };
    };

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
