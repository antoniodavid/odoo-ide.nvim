-- odoo-ide.nvim: Context Detection Module
-- Detects Odoo version, file location, model info for smart snippets

local M = {}
local utils = require("odoo-ide.utils")

-- Cache for performance
M._cache = {
  version = nil,
  manifest_path = nil,
  last_check = 0,
}

-- Cache TTL in seconds
local CACHE_TTL = 5

---Find the nearest __manifest__.py file
---@return string|nil manifest_path
function M.find_manifest()
  local current = utils.get_current_dir()
  
  local search_dir = current
  while search_dir and search_dir ~= "/" do
    local manifest_path = search_dir .. "/__manifest__.py"
    local f = io.open(manifest_path, "r")
    if f then
      f:close()
      return manifest_path
    end
    search_dir = vim.fn.fnamemodify(search_dir, ":h")
  end
  return nil
end

---Get addon root directory from manifest
---@return string|nil addon_root
function M.get_addon_root()
  local manifest = M.find_manifest()
  if manifest then
    return vim.fn.fnamemodify(manifest, ":h")
  end
  return nil
end

---Detect Odoo version from __manifest__.py
---@return number|nil version (e.g., 17, 18, 16)
function M.get_odoo_version()
  local now = os.time()
  
  -- Return cached version if still valid
  if M._cache.version and (now - M._cache.last_check) < CACHE_TTL then
    return M._cache.version
  end
  
  local manifest = M.find_manifest()
  if not manifest then
    return nil
  end
  
  -- Read manifest content
  local file = io.open(manifest, "r")
  if not file then
    return nil
  end
  
  local content = file:read("*all")
  file:close()
  
  local version_str = content:match([[['"version['"]%s*:%s*['"](%d+)%.]])
  
  if version_str then
    local version = tonumber(version_str)
    -- Update cache
    M._cache.version = version
    M._cache.manifest_path = manifest
    M._cache.last_check = now
    return version
  end
  
  return nil
end

---Detect current file location type
---@return string location_type: "models", "wizards", "controllers", "tests", "views", "security", "static", "other"
function M.get_file_location()
  local filepath = vim.fn.expand("%:p")
  local addon_root = M.get_addon_root()
  
  if not addon_root then
    return "other"
  end
  
  -- Get relative path from addon root
  local relative = filepath:sub(#addon_root + 2)
  
  -- Detect location by directory
  if relative:match("^models/") or relative:match("^models%.py$") then
    return "models"
  elseif relative:match("^wizards?/") then
    return "wizards"
  elseif relative:match("^controllers?/") then
    return "controllers"
  elseif relative:match("^tests?/") then
    return "tests"
  elseif relative:match("^views?/") then
    return "views"
  elseif relative:match("^security/") then
    return "security"
  elseif relative:match("^static/") then
    return "static"
  elseif relative:match("^reports?/") then
    return "reports"
  elseif relative:match("^data/") then
    return "data"
  elseif relative:match("^demo/") then
    return "demo"
  end
  
  return "other"
end

---Get model info from current buffer
---@return table model_info {name: string|nil, inherit: string|nil, fields: string[], type: string}
function M.get_model_info()
  local info = {
    name = nil,
    inherit = nil,
    inherits = nil,
    fields = {},
    type = "Model", -- Model, TransientModel, AbstractModel
  }
  
  local lines = vim.api.nvim_buf_get_lines(0, 0, 200, false)
  
  for _, line in ipairs(lines) do
    -- Detect _name = 'model.name'
    if not info.name then
      local name = line:match("_name%s*=%s*['\"]([%w%.]+)['\"]")
      if name then
        info.name = name
      end
    end
    
    -- Detect _inherit = 'model.name' (single inherit)
    if not info.inherit then
      local inherit = line:match("_inherit%s*=%s*['\"]([%w%.]+)['\"]")
      if inherit then
        info.inherit = inherit
      end
    end
    
    -- Detect _inherits = {'model.name': 'field_id'}
    if not info.inherits then
      local inherits = line:match("_inherits%s*=%s*{['\"]([%w%.]+)['\"]")
      if inherits then
        info.inherits = inherits
      end
    end
    
    -- Detect model type from class definition
    local model_type = line:match("models%.(%w+)")
    if model_type then
      if model_type == "TransientModel" then
        info.type = "TransientModel"
      elseif model_type == "AbstractModel" then
        info.type = "AbstractModel"
      end
    end
    
    -- Detect field definitions
    local field_name = line:match("^%s*([%w_]+)%s*=%s*fields%.")
    if field_name then
      table.insert(info.fields, field_name)
    end
  end
  
  return info
end

---Get list of fields defined in current buffer
---@return string[] fields list of field names
function M.get_fields()
  return M.get_model_info().fields
end

---Check if current buffer has a compute method for a field
---@param field_name string
---@return boolean
function M.has_compute_method(field_name)
  local method_name = "_compute_" .. field_name
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  
  for _, line in ipairs(lines) do
    if line:match("def%s+" .. method_name .. "%s*%(") then
      return true
    end
  end
  
  return false
end

---Find orphan computes (compute='_compute_x' without def _compute_x)
---@return table[] orphans {field: string, method: string}
function M.find_orphan_computes()
  local orphans = {}
  local computes = {}
  local methods = {}
  
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  
  for _, line in ipairs(lines) do
    -- Find compute='_compute_xxx' or compute="_compute_xxx"
    local compute_method = line:match("compute%s*=%s*['\"](_compute_[%w_]+)['\"]")
    if compute_method then
      computes[compute_method] = true
    end
    
    -- Find def _compute_xxx(self):
    local method_name = line:match("def%s+(_compute_[%w_]+)%s*%(")
    if method_name then
      methods[method_name] = true
    end
  end
  
  -- Find computes without methods
  for compute, _ in pairs(computes) do
    if not methods[compute] then
      -- Extract field name from method name
      local field = compute:gsub("^_compute_", "")
      table.insert(orphans, { field = field, method = compute })
    end
  end
  
  return orphans
end

---Get full context for smart snippets
---@return table context
function M.get_context()
  return {
    version = M.get_odoo_version(),
    location = M.get_file_location(),
    model = M.get_model_info(),
    addon_root = M.get_addon_root(),
    filetype = vim.bo.filetype,
  }
end

---Check if we're in an Odoo project
---@return boolean
function M.is_odoo_project()
  return M.find_manifest() ~= nil
end

---Debug: Print current context
function M.debug()
  local ctx = M.get_context()
  vim.notify(vim.inspect(ctx), vim.log.levels.INFO)
end

return M
