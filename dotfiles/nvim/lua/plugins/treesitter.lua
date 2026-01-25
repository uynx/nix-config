return {
  "nvim-treesitter/nvim-treesitter",
  opts = function(_, opts)
    -- Extend the default ensure_installed list
    if type(opts.ensure_installed) == "table" then
      vim.list_extend(opts.ensure_installed, {
        "bash",
        "html",
        "javascript",
        "json",
        "lua",
        "markdown",
        "markdown_inline",
        "python",
        "query",
        "regex",
        "tsx",
        "typescript",
        "vim",
        "vimdoc",
        "yaml",
        "css",
        "latex",
        "scss",
        "svelte",
        "vue",
        "norg",
        "typst",
        "html",
      })
    end
  end,
}
