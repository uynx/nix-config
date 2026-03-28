-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
vim.opt.rtp:append(vim.fn.expand("~/.local/share/nvim/site/"))
