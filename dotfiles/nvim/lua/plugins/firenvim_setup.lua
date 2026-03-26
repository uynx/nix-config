return {
  "glacambre/firenvim",
  lazy = false,
  init = function()
    vim.g.firenvim_config = {
      globalSettings = { ["alt"] = "all" },
      localSettings = {
        [".*"] = { takeover = "never", priority = 0 },
      },
    }
  end,
  config = function()
    if not vim.g.started_by_firenvim then
      return
    end

    vim.o.guifont = "Hack Nerd Font:h20"

    local function detect_language()
      local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, 20, false), "\n")
      if content:match("func [%w_]+%(") and content:match("%) [%w%[%]]+ {") then
        return "go"
      end
      if content:match("class [%w_]+%:") or content:match("def [%w_]+%(self") then
        return "python"
      end
      if content:match("impl Solution") or content:match("pub fn ") or content:match("%%->") then
        return "rust"
      end
      if content:match("%%: [%w%[%]]+") or content:match("%)%: [%w_]+") then
        return "typescript"
      end
      if content:match("public class [%w_]+") or content:match("public [%w%[%]]+ [%w_]+%(") then
        return "java"
      end
      if content:match("public%:") or content:match("vector<") then
        return "cpp"
      end
      return nil
    end

    local function set_language(lang)
      vim.bo.filetype = lang
    end

    vim.api.nvim_create_autocmd({ "BufEnter", "BufReadPost" }, {
      pattern = { "*leetcode.com_*.txt" },
      callback = function()
        if vim.bo.filetype == "text" or vim.bo.filetype == "" then
          local lang = detect_language()
          if lang then
            set_language(lang)
          end
        end
      end,
    })

    vim.keymap.set("n", "<leader>fl", function()
      vim.ui.select(
        { "python", "cpp", "java", "typescript", "rust", "go", "text" },
        { prompt = "Force Language:" },
        function(choice)
          if choice then
            set_language(choice)
          end
        end
      )
    end, { desc = "Firenvim: Set language" })
  end,
}
