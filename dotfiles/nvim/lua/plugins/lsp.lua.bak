return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "shfmt",
        "stylua",
        "shellcheck",
        "lua-language-server",
        "html-lsp",
        "css-lsp",
        "json-lsp",
        "eslint-lsp",
        "yaml-language-server",
        "bash-language-server",
        "marksman",
        "pyright",
        "gopls",
        "taplo",
        "nil",
      })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- The following are handled by LazyVim extras or have sensible defaults.
        -- We only list them here to ensure Mason installs them.
        lua_ls = {},
        html = {},
        cssls = {},
        jsonls = {},
        yamlls = {},
        bashls = {},
        marksman = {},
        pyright = {},
        gopls = {},
        taplo = {},
        nil_ls = {},
        eslint = {
          settings = {
            -- help eslint find the working directory for monorepos
            workingDirectory = { mode = "auto" },
          },
        },
      },
    },
  },
}
