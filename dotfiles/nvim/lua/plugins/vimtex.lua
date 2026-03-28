return {
  "lervag/vimtex",
  lazy = false, -- VimTeX should not be lazy loaded for best functionality
  config = function()
    -- Set the viewer to Sioyek
    vim.g.vimtex_view_method = "sioyek"
    
    -- Configure the compiler (using latexmk, which you have via Nix)
    vim.g.vimtex_compiler_method = "latexmk"
    
    -- Extra compiler options (optional, but recommended for clean builds)
    vim.g.vimtex_compiler_latexmk = {
      options = {
        "-pdflua", -- Use LuaLaTeX instead of pdfLaTeX
        "-shell-escape",
        "-verbose",
        "-file-line-error",
        "-synctex=1",
        "-interaction=nonstopmode",
      },
    }

    -- This setting ensures inverse search works out of the box with Neovim
    vim.g.vimtex_callback_progname = "nvim"
  end,
}
