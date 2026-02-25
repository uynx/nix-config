return {
  {
    "nvim-neorg/neorg",
    version = "*",
    lazy = false,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "nvim-neorg/lua-utils.nvim",
      "pysan3/pathlib.nvim",
      "nvim-neotest/nvim-nio",
      "MunifTanjim/nui.nvim",
    },
    config = function()
      require("neorg").setup({
        load = {
          ["core.defaults"] = {},
          ["core.concealer"] = {},
          ["core.dirman"] = {
            config = {
              workspaces = {
                notes = "~/notes",
              },
              default_workspace = "notes",
            },
          },
          ["core.keybinds"] = {
            config = {
              hook = function(keybinds)
                -- Map demote/promote to use Alt/Option instead of < / > to avoid conflicts
                keybinds.remap_event("norg", "n", "<M-,>", "core.promo.demote")
                keybinds.remap_event("norg", "n", "<M-.>", "core.promo.promote")
                -- Map todo cycle to Alt+Space instead of Ctrl+Space (usually used by completion)
                keybinds.remap_event("norg", "n", "<M-Space>", "core.qol.todo-items.todo.task-cycle")
              end,
            },
          },
          -- This prevents Neorg from trying to manage parsers manually
          -- because we are handling them via Nix/Treesitter.
          ["core.integrations.treesitter"] = {
            config = {
              install_parsers = false,
            },
          },
        },
      })
    end,
  },
}
