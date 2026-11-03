-- odoo-ide.nvim: Shared filesystem helpers

local M = {}

---Remove trailing slashes from a path.
---@param path string
---@return string
local function strip_trailing_slash(path)
  return (path:gsub("/+$", ""))
end

---Resolve the real filesystem directory of the current buffer.
---
---Virtual buffers are not filesystem paths: oil.nvim (and similar explorers)
---name their buffers with a URI such as `oil:///project/subdir`. Feeding that
---URI to `vim.fs.find(..., { upward = true })` makes every upward search fail,
---so Doodba roots are not detected when Neovim starts on a directory.
---
---@return string directory Absolute path used as the start of upward searches
function M.get_current_dir()
  local name = vim.api.nvim_buf_get_name(0)

  if name == "" then
    return vim.fn.getcwd()
  end

  local scheme = name:match("^(%a[%w+.-]*)://")
  if scheme then
    if scheme == "oil" then
      local dir = name:match("^oil://(.+)$")
      if dir and dir ~= "" then
        dir = strip_trailing_slash(vim.fn.fnamemodify(dir, ":p"))
        if vim.fn.isdirectory(dir) == 1 then
          return dir
        end
      end
    end
    -- Any other virtual URI has no filesystem directory of its own.
    return vim.fn.getcwd()
  end

  -- Directory buffers (netrw and friends) use the directory as buffer name.
  if vim.fn.isdirectory(name) == 1 then
    return strip_trailing_slash(vim.fn.fnamemodify(name, ":p"))
  end

  local dir = vim.fn.fnamemodify(name, ":p:h")
  if dir ~= "" and vim.fn.isdirectory(dir) == 1 then
    return strip_trailing_slash(dir)
  end

  return vim.fn.getcwd()
end

return M
