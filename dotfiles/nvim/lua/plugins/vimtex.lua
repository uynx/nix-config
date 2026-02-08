return {
  "lervag/vimtex",
  lazy = false, -- Load immediately to ensure filetype detection works
  init = function()
    -- Use Tectonic as the compiler (modern, self-contained)
    vim.g.vimtex_compiler_method = "tectonic"

    -- Use Skim as the PDF viewer (supports auto-reload and sync with Neovim)
    vim.g.vimtex_view_method = "skim"
  end,
}
