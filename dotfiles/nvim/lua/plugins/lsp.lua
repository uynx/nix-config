return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      nil_ls = {
        mason = false,
        settings = {
          ["nil"] = {
            nix = {
              flake = {
                autoArchive = true,
              },
            },
          },
        },
      },
      lua_ls = {},
      pyright = {},
      ruff = {},
      jsonls = {},
    },
  },
}
