-- odoo-ide.nvim: LuaSnip Integration Module
-- Context-aware snippets for Odoo development

local M = {}

local context = require("odoo-ide.context")

---Check if LuaSnip is available
---@return boolean
local function has_luasnip()
  local ok, _ = pcall(require, "luasnip")
  return ok
end

---Setup LuaSnip snippets for Odoo
---@param opts table|nil options
function M.setup(opts)
  opts = opts or {}

  if not has_luasnip() then
    vim.notify("odoo-ide: LuaSnip not found. Snippets disabled.", vim.log.levels.WARN)
    return
  end

  -- Load snippet collections
  require("odoo-ide.snippets.python").setup()
  require("odoo-ide.snippets.xml").setup()
  require("odoo-ide.snippets.js").setup()

  vim.notify("odoo-ide: Snippets loaded", vim.log.levels.INFO)
end

---Get current Odoo version (exposed for snippets)
---@return number|nil
function M.get_version()
  return context.get_odoo_version()
end

---Get model info (exposed for snippets)
---@return table
function M.get_model_info()
  return context.get_model_info()
end

---Get file location (exposed for snippets)
---@return string
function M.get_location()
  return context.get_file_location()
end

---Check if in Odoo project (condition for snippets)
---@return boolean
function M.is_odoo()
  return context.is_odoo_project()
end

return M
