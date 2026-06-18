return {
  "folke/noice.nvim",
  enabled = not vim.g.started_by_firenvim,
  opts = {
    lsp = {
      progress = {
        enabled = false,
      },
    },
  },
}
