return {
  "nvim-lualine/lualine.nvim",
  opts = function(_, opts)
    -- Remove the default clock component from the far right section (lualine_z)
    opts.sections = opts.sections or {}
    opts.sections.lualine_z = {}
  end,
}
