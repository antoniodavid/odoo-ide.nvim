-- odoo-ide.nvim: Shared filesystem helpers

local M = {}

---Read a file, returning nil when it cannot be opened.
---@param path string
---@return string|nil
function M.read_file(path)
  local fd = io.open(path, "r")
  if not fd then
    return nil
  end
  local content = fd:read("*a")
  fd:close()
  return content
end

---Write a file atomically, and only when its content actually changes.
---@param path string
---@param content string
---@return boolean ok
---@return boolean|string changed Whether the file was written, or an error message
function M.write_if_changed(path, content)
  if M.read_file(path) == content then
    return true, false
  end

  local dir = vim.fn.fnamemodify(path, ":h")
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end

  local tmp = path .. ".tmp"
  local fd = io.open(tmp, "w")
  if not fd then
    return false, "cannot open " .. tmp .. " for writing"
  end

  fd:write(content)
  fd:close()

  local ok = os.rename(tmp, path)
  if not ok then
    -- Windows cannot rename over an existing file.
    os.remove(path)
    ok = os.rename(tmp, path)
  end

  if not ok then
    os.remove(tmp)
    return false, "cannot replace " .. path
  end

  return true, true
end

---Render a path relative to a base directory, in the `./...` form Odoo tools
---expect for portable configuration files.
---@param full_path string
---@param base_path string
---@return string
function M.relative_path(full_path, base_path)
  local base = (base_path:gsub("/+$", ""))

  if full_path == base then
    return "./"
  end

  local prefix = base .. "/"
  if full_path:sub(1, #prefix) == prefix then
    return "./" .. full_path:sub(#prefix + 1)
  end

  return full_path
end

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
