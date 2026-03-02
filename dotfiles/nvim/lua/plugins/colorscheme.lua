return {
  -- Install the official Flexoki theme plugin by kepano
  {
    "kepano/flexoki-neovim",
    name = "flexoki",
  },
  -- Configure LazyVim to use it as the default colorscheme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "flexoki",
    },
  },
}
