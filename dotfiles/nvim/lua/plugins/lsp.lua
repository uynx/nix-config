return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      nil_ls = {
        mason = false, -- Tell LazyVim NOT to use Mason to install this
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
    },
  },
}
