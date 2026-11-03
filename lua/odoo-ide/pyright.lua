local M = {}
local project = require("odoo-ide.project")
local utils = require("odoo-ide.utils")

function M.generate_config(opts)
  opts = opts or {}

  local current = opts.project or project.get()
  if not current then
    return nil, "Not in an Odoo project"
  end

  local paths = project.paths(current, {
    include_all_repos = opts.include_all_repos,
  })

  if #paths == 0 then
    return nil, "No Odoo paths found"
  end

  local use_relative = opts.use_relative_paths ~= false
  local extra_paths = {}

  for _, path in ipairs(paths) do
    local final_path = use_relative and utils.relative_path(path, current.root) or path
    table.insert(extra_paths, final_path)
  end

  local exec_root = use_relative and "." or current.root

  local config = {
    include = extra_paths,
    exclude = { "**/__pycache__" },
    ignore = { "**/__pycache__" },
    reportMissingImports = true,
    reportMissingTypeStubs = false,
    pythonVersion = opts.python_version or "3.10",
    pythonPlatform = "Linux",
    executionEnvironments = {
      {
        root = exec_root,
        extraPaths = extra_paths,
      },
    },
  }

  return vim.json.encode(config), nil
end

---Write pyrightconfig.json, skipping identical content.
---@param opts? table
---@return boolean ok
---@return string|nil path_or_error
---@return boolean|nil changed
function M.write_config(opts)
  opts = opts or {}

  local current = opts.project or project.get()
  if not current then
    return false, "Not in an Odoo project"
  end

  local output_path = opts.output_path or project.config_dir(current)
  local config_file = output_path .. "/pyrightconfig.json"

  local content, err = M.generate_config(opts)
  if not content then
    return false, err
  end

  local ok, changed = utils.write_if_changed(config_file, content)
  if not ok then
    return false, changed
  end

  return true, config_file, changed
end

---Generate the configuration when it is missing or its content is stale.
---@param opts? table
---@return string|nil path
function M.ensure_config(opts)
  opts = opts or {}

  local current = opts.project or project.get()
  if not current then
    return nil
  end

  local ok, path = M.write_config(vim.tbl_extend("force", opts, { project = current }))
  if ok then
    return path
  end

  local config_file = (opts.output_path or project.config_dir(current)) .. "/pyrightconfig.json"
  if vim.fn.filereadable(config_file) == 1 then
    return config_file
  end

  return nil
end

function M.setup_commands()
  vim.api.nvim_create_user_command("OdooGeneratePyrightConfig", function(cmd_opts)
    local opts = {
      include_all_repos = cmd_opts.args:match("all") ~= nil,
    }

    local success, result = M.write_config(opts)
    if success then
      vim.notify("odoo-ide: Generated " .. result, vim.log.levels.INFO)
    else
      vim.notify("odoo-ide: " .. result, vim.log.levels.ERROR)
    end
  end, {
    bang = true,
    nargs = "?",
    desc = "Generate pyrightconfig.json for the current Odoo project",
  })
end

return M
