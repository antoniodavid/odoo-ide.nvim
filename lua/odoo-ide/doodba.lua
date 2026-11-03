local M = {}
local utils = require("odoo-ide.utils")

local function file_exists(path)
  return vim.fn.filereadable(path) == 1
end

local function dir_exists(path)
  return vim.fn.isdirectory(path) == 1
end

function M.find_root()
  local current = utils.get_current_dir()

  local root = vim.fs.find("common.yaml", { path = current, upward = true, type = "file" })[1]
  if root then
    return vim.fs.dirname(root)
  end
  
  root = vim.fs.find("docker-compose.yml", { path = current, upward = true, type = "file" })[1]
  if root then
    return vim.fs.dirname(root)
  end

  return nil
end

function M.is_doodba()
  return M.find_root() ~= nil
end

local function read_yaml_simple(filepath)
  if not file_exists(filepath) then
    return nil
  end

  local lines = vim.fn.readfile(filepath)
  local result = {}
  local current_key = nil

  for _, line in ipairs(lines) do
    if line:match("^#") or line:match("^%s*$") then
      goto continue
    end

    local key = line:match("^([%w_%-%.]+):%s*$")
    if key then
      current_key = key
      result[current_key] = {}
      goto continue
    end

    local inline_key, inline_val = line:match("^([%w_%-%.]+):%s*(.+)$")
    if inline_key and inline_val then
      result[inline_key] = inline_val
      current_key = nil
      goto continue
    end

    if current_key then
      local item = line:match("^%s*%-%s*[\"']?([^\"']+)[\"']?%s*$")
      if item then
        table.insert(result[current_key], item)
      end
    end

    ::continue::
  end

  return result
end

function M.find_odoo_path(src_path)
  local candidates = {
    src_path .. "/odoo",
    src_path .. "/OCB",
  }

  for _, candidate in ipairs(candidates) do
    if file_exists(candidate .. "/odoo-bin") or file_exists(candidate .. "/odoo/api.py") then
      return candidate
    end
  end

  return nil
end

function M.get_paths(opts)
  opts = opts or {}
  local root = M.find_root()
  if not root then return {} end

  local paths = {}
  local seen = {}
  
  local function add_path(path)
    if not seen[path] and dir_exists(path) then
      seen[path] = true
      table.insert(paths, path)
    end
  end

  local src_path = root .. "/odoo/custom/src"

  -- 2. Odoo core addons
  local odoo_path = M.find_odoo_path(src_path)
  if odoo_path then
    add_path(odoo_path .. "/addons")
    add_path(odoo_path .. "/odoo/addons")
  end

  -- 2.5. ALWAYS include private folder (custom modules)
  local private_path = src_path .. "/private"
  if dir_exists(private_path) then
    add_path(private_path)
  end

  -- 3. Addons from addons.yaml
  local addons_yaml = src_path .. "/addons.yaml"
  local yaml_content = read_yaml_simple(addons_yaml)
  if yaml_content then
    for repo_name, modules in pairs(yaml_content) do
      local include_repo = false
      if type(modules) == "table" and #modules > 0 then
        include_repo = true
      elseif type(modules) == "string" and modules ~= "" then
        include_repo = true
      end
      
      if include_repo then
        local repo_path
        if repo_name:sub(1, 2) == "./" then
          repo_path = src_path .. "/" .. repo_name:sub(3)
        else
          repo_path = src_path .. "/" .. repo_name
        end
        add_path(repo_path)
      end
    end
  end

  -- 4. Include all repos if requested
  if opts.include_all_repos then
    local exclude_list = { "private", "odoo", "OCB" }
    local exclude_set = {}
    for _, v in ipairs(exclude_list) do exclude_set[v] = true end

    local handle = vim.loop.fs_scandir(src_path)
    if handle then
      while true do
        local name, type = vim.loop.fs_scandir_next(handle)
        if not name then break end
        if type == "directory" and not exclude_set[name] then
          local repo_path = src_path .. "/" .. name
          -- Check for modules
          local sub_handle = vim.loop.fs_scandir(repo_path)
          if sub_handle then
            while true do
              local sub_name, sub_type = vim.loop.fs_scandir_next(sub_handle)
              if not sub_name then break end
              if sub_type == "directory" then
                if file_exists(repo_path .. "/" .. sub_name .. "/__manifest__.py") or
                   file_exists(repo_path .. "/" .. sub_name .. "/__openerp__.py") then
                  add_path(repo_path)
                  break
                end
              end
            end
          end
        end
      end
    end
  end

  return paths
end

return M
