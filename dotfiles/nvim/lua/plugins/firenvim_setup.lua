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

    vim.o.guifont = "Hack Nerd Font:h16"

    local ext_map =
      { python = "py", cpp = "cpp", java = "java", typescript = "ts", rust = "rs", go = "go", text = "txt" }
    local ft_locks = {}

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

    local function set_language(lang, is_auto)
      local bufnr = vim.api.nvim_get_current_buf()
      local old_name = vim.api.nvim_buf_get_name(bufnr)
      ft_locks[bufnr] = true

      for _, c in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
        vim.lsp.stop_client(c.id)
      end

      math.randomseed(os.time())
      local tmp_name = old_name .. "." .. math.random(1000, 9999) .. "." .. (ext_map[lang] or lang)

      local function clean_buffer(n)
        for _, b in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_get_name(b) == n and b ~= bufnr then
            vim.cmd("silent! bwipeout! " .. b)
          end
        end
        os.remove(n)
      end

      clean_buffer(tmp_name)
      vim.bo.modified = false
      pcall(vim.api.nvim_buf_set_name, bufnr, tmp_name)
      vim.bo.filetype = lang

      vim.schedule(function()
        pcall(vim.cmd, "LspStart")
        vim.defer_fn(function()
          if not vim.api.nvim_buf_is_valid(bufnr) then
            return
          end
          vim.bo.modified = false
          clean_buffer(old_name)
          pcall(vim.api.nvim_buf_set_name, bufnr, old_name)
          vim.bo.filetype, vim.bo.modified = lang, false
          if is_auto then
            vim.notify("Firenvim: Detected " .. lang, 2)
          end
        end, 200)
      end)
    end

    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client.name == "eslint" then
          vim.lsp.stop_client(args.data.client_id)
        end
      end,
    })

    vim.api.nvim_create_autocmd({ "BufEnter", "BufReadPost" }, {
      pattern = { "*leetcode.com_*.txt", "*neetcode.io_*.txt" },
      callback = function()
        local bufnr = vim.api.nvim_get_current_buf()
        if ft_locks[bufnr] then
          return
        end
        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(bufnr) then
            return
          end
          if vim.bo.filetype == "text" or vim.bo.filetype == "" or vim.bo.filetype == "txt" then
            local lang = detect_language()
            if lang then
              set_language(lang, true)
            end
          end
        end)
      end,
    })

    vim.keymap.set("n", "<leader>fl", function()
      vim.ui.select(
        { "python", "cpp", "java", "typescript", "rust", "go", "text" },
        { prompt = "Language:" },
        function(c)
          if c then
            set_language(c, false)
          end
        end
      )
    end, { desc = "Firenvim: Set language" })
  end,
}
