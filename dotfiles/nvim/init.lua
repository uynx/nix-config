-- Register custom filetypes before anything else loads
vim.filetype.add({
  extension = {
    jsx = "javascriptreact",
    tsx = "typescriptreact",
    mdx = "markdown.mdx",
    gotmpl = "gotmpl",
    gowork = "gowork",
  },
  -- Register literal names used by LSPs to silence checkhealth warnings
  filename = {
    ["javascript.jsx"] = "javascriptreact",
    ["typescript.tsx"] = "typescriptreact",
    ["markdown.mdx"] = "markdown.mdx",
    ["gowork"] = "gowork",
    ["gotmpl"] = "gotmpl",
    ["yaml.docker-compose"] = "yaml.docker-compose",
    ["yaml.gitlab"] = "yaml.gitlab",
    ["yaml.helm-values"] = "yaml.helm-values",
  },
  pattern = {
    [".*docker%-compose.*%.yml"] = "yaml.docker-compose",
    [".*docker%-compose.*%.yaml"] = "yaml.docker-compose",
    [".*gitlab%-ci%.yml"] = "yaml.gitlab",
    [".*helm.*/values%.yaml"] = "yaml.helm-values",
  },
})

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
