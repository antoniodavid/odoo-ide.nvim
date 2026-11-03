-- odoo-ide.nvim: project detection
--
-- Resolves the Odoo project that owns the current buffer. Two kinds are
-- supported: Doodba environments (docker-compose based) and local projects
-- (an Odoo checkout or a plain addons repository).

local M = {}
local utils = require("odoo-ide.utils")
local doodba = require("odoo-ide.doodba")

local CACHE_TTL = 5

local _cache = {
  dir = nil,
  project = nil,
  last_check = 0,
}

local function file_exists(path)
  return path ~= nil and vim.fn.filereadable(path) == 1
end

local function dir_exists(path)
  return path ~= nil and vim.fn.isdirectory(path) == 1
end

local function uniq(list)
  local seen, out = {}, {}
  for _, value in ipairs(list) do
    if value ~= "" and not seen[value] then
      seen[value] = true
      table.insert(out, value)
    end
  end
  return out
end

---Read the Odoo major version from a Doodba common.yaml.
---@param root string
---@return number|nil
local function version_from_common_yaml(root)
  local path = root .. "/common.yaml"
  if not file_exists(path) then
    return nil
  end

  local fd = io.open(path, "r")
  if not fd then
    return nil
  end
  local content = fd:read("*a") or ""
  fd:close()

  local major = content:match('ODOO_VERSION:%s*["\']?(%d+)')
  return major and tonumber(major) or nil
end

---Read the Odoo major version from a checkout release.py.
---@param odoo_path string|nil directory that contains the `odoo` package
---@return number|nil
local function version_from_release(odoo_path)
  if not odoo_path then
    return nil
  end

  local path = odoo_path .. "/odoo/release.py"
  if not file_exists(path) then
    return nil
  end

  local fd = io.open(path, "r")
  if not fd then
    return nil
  end
  local content = fd:read("*a") or ""
  fd:close()

  local major = content:match("version_info%s*=%s*%(%s*(%d+)")
  return major and tonumber(major) or nil
end

---Read `addons_path` entries from an Odoo configuration file.
---@param path string
---@return string[]
local function addons_from_conf(path)
  if not file_exists(path) then
    return {}
  end

  local fd = io.open(path, "r")
  if not fd then
    return {}
  end

  local paths = {}
  for line in fd:lines() do
    local value = line:match("^%s*addons_path%s*=%s*(.+)$")
    if value then
      for entry in value:gmatch("[^,]+") do
        local trimmed = vim.trim(entry)
        if trimmed ~= "" then
          local expanded = vim.fn.expand(trimmed)
          -- Relative entries are relative to the configuration file.
          if expanded:sub(1, 1) ~= "/" then
            expanded = vim.fn.fnamemodify(path, ":h") .. "/" .. expanded
          end
          table.insert(paths, expanded)
        end
      end
    end
  end
  fd:close()

  return paths
end

---Candidate paths for odoo.conf / .odoorc, in lookup order.
---@param root string|nil
---@param dir string
---@return string[]
local function conf_candidates(root, dir)
  local candidates = { dir .. "/odoo.conf" }

  if root and root ~= dir then
    table.insert(candidates, root .. "/odoo.conf")
  end

  local env_conf = vim.env.ODOO_RC
  if env_conf and env_conf ~= "" then
    table.insert(candidates, vim.fn.expand(env_conf))
  end

  table.insert(candidates, vim.fn.expand("~/.odoorc"))
  return candidates
end

---Walk upwards looking for an Odoo checkout root.
---@param start string
---@return string|nil root
local function find_checkout(start)
  local dir = start

  while dir and dir ~= "" do
    if file_exists(dir .. "/odoo-bin") then
      return dir
    end

    if file_exists(dir .. "/odoo/release.py") and dir_exists(dir .. "/odoo") then
      return dir
    end

    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then
      break
    end
    dir = parent
  end

  return nil
end

---Walk upwards looking for the repository that contains the current addon.
---@param start string
---@return string|nil repo_root
local function find_addon_repo(start)
  local manifest = vim.fs.find("__manifest__.py", { path = start, upward = true, type = "file" })[1]
  if not manifest then
    return nil
  end

  return vim.fn.fnamemodify(manifest, ":h:h")
end

---Build the project descriptor.
---@param kind "doodba"|"local"
---@param root string
---@param odoo_path string|nil
---@param addons string[]
---@param version number|nil
---@return table
local function build(kind, root, odoo_path, addons, version)
  return {
    kind = kind,
    root = vim.fs.normalize(root),
    odoo_path = odoo_path and vim.fs.normalize(odoo_path) or nil,
    addons_paths = uniq(addons),
    version = version,
  }
end

---Collect addons paths declared in Odoo configuration files.
---@param root string|nil
---@param dir string
---@return string[]
local function conf_paths(root, dir)
  local seen, paths = {}, {}

  for _, candidate in ipairs(conf_candidates(root, dir)) do
    for _, path in ipairs(addons_from_conf(candidate)) do
      local absolute = vim.fs.normalize(path)
      if not seen[absolute] and dir_exists(absolute) then
        seen[absolute] = true
        table.insert(paths, absolute)
      end
    end
  end

  return paths
end

---Detect the Odoo project for a directory.
---@param opts? { dir?: string }
---@return table|nil project
function M.detect(opts)
  opts = opts or {}
  local dir = opts.dir or utils.get_current_dir()

  -- Doodba first: a checkout inside a Doodba environment must resolve to the
  -- environment, not to the vendored odoo copy.
  local doodba_root = doodba.find_root(dir)
  if doodba_root then
    local addons = doodba.get_paths()
    local odoo_path = doodba.find_odoo_path(doodba_root .. "/odoo/custom/src")
    for _, path in ipairs(conf_paths(doodba_root, dir)) do
      table.insert(addons, path)
    end
    local version = version_from_common_yaml(doodba_root) or version_from_release(odoo_path)
    return build("doodba", doodba_root, odoo_path, addons, version)
  end

  -- Local Odoo checkout.
  local checkout = find_checkout(dir)
  if checkout then
    local addons = {}
    for _, path in ipairs(conf_paths(checkout, dir)) do
      table.insert(addons, path)
    end
    table.insert(addons, checkout .. "/addons")
    table.insert(addons, checkout .. "/odoo/addons")
    return build("local", checkout, checkout, addons, version_from_release(checkout))
  end

  -- Plain addons repository: no Odoo core, only the modules being developed.
  local repo = find_addon_repo(dir)
  if repo then
    local addons = conf_paths(repo, dir)
    table.insert(addons, repo)
    return build("local", repo, nil, addons, nil)
  end

  return nil
end

---Detected project for the current buffer, cached for a few seconds.
---@return table|nil project
function M.get()
  local dir = utils.get_current_dir()
  local now = os.time()

  if _cache.dir == dir and (now - _cache.last_check) < CACHE_TTL then
    return _cache.project
  end

  local project = M.detect({ dir = dir })
  _cache.dir = dir
  _cache.project = project
  _cache.last_check = now

  return project
end

---Clear the detection cache.
function M.reset()
  _cache.dir = nil
  _cache.project = nil
  _cache.last_check = 0
end

---Whether the project is a Doodba environment.
---@param project table|nil
---@return boolean
function M.is_doodba(project)
  return project ~= nil and project.kind == "doodba"
end

---Where generated configuration files belong for a project.
---
---Doodba environments own the repository root. A local checkout is usually a
---clone of Odoo itself, so writing there would dirty an upstream tree: use the
---current working directory (the addon repository being developed) instead.
---@param current table
---@return string
function M.config_dir(current)
  if M.is_doodba(current) then
    return current.root
  end

  return vim.fs.normalize(vim.fn.getcwd())
end

---Addons paths for a project, optionally scanning every repository of a
---Doodba environment.
---@param project table
---@param opts? { include_all_repos?: boolean }
---@return string[]
function M.paths(project, opts)
  opts = opts or {}

  if M.is_doodba(project) and opts.include_all_repos then
    local paths = doodba.get_paths({ include_all_repos = true })
    for _, path in ipairs(project.addons_paths) do
      if not vim.tbl_contains(paths, path) then
        table.insert(paths, path)
      end
    end
    return paths
  end

  return project.addons_paths
end

return M
