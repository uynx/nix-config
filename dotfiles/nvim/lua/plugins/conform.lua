return {
  "stevearc/conform.nvim",
  opts = {
    formatters = {
      ["markdown-toc"] = {
        condition = function(_, ctx)
          return true
        end,
      },
      ["markdownlint-cli2"] = {
        condition = function(_, ctx)
          return true
        end,
      },
    },
  },
}
