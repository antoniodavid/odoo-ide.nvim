local M = {}
local doodba = require("odoo-ide.doodba")

local function get_relative_path(full_path, base_path)
  if full_path:sub(1, #base_path) == base_path then
    local rel = full_path:sub(#base_path + 1)
    if rel:sub(1, 1) == "/" then
      rel = rel:sub(2)
    end
    return "./" .. rel
  end
  return full_path
end

function M.generate_config(opts)
  opts = opts or {}
  
  local root = doodba.find_root()
  if not root then
    return nil, "Not in a Doodba project"
  end

  local paths = doodba.get_paths({
    include_all_repos = opts.include_all_repos
  })
  
  if #paths == 0 then
    return nil, "No Odoo paths found"
  end

  local use_relative = opts.use_relative_paths ~= false
  local extra_paths = {}

  for _, path in ipairs(paths) do
    local final_path = use_relative and get_relative_path(path, root) or path
    table.insert(extra_paths, final_path)
  end
  
  local exec_root = use_relative and "." or root

  local config = {
    include = { "odoo/custom/src" },
    exclude = { "**/__pycache__" },
    ignore = { "**/__pycache__" },
    reportMissingImports = true,
    reportMissingTypeStubs = false,
    pythonVersion = "3.10",
    pythonPlatform = "Linux",
    executionEnvironments = {
      {
        root = exec_root,
        extraPaths = extra_paths,
      }
    }
  }

  return vim.json.encode(config), nil
end

function M.write_config(opts)
  opts = opts or {}
  
  local root = doodba.find_root()
  if not root then
    return false, "Not in a Doodba project"
  end

  local output_path = opts.output_path or root
  local config_file = output_path .. "/pyrightconfig.json"

  if vim.fn.filereadable(config_file) == 1 and not opts.force_regenerate then
    return true, "Config already exists at " .. config_file
  end

  local content, err = M.generate_config(opts)
  if not content then
    return false, err
  end

  local file = io.open(config_file, "w")
  if not file then
    return false, "Failed to open " .. config_file .. " for writing"
  end

  file:write(content)
  file:close()

  if vim.fn.executable("python3") == 1 then
    local tmp_file = config_file .. ".tmp"
    local cmd = string.format("cat %s | python3 -m json.tool > %s && mv %s %s", 
      vim.fn.shellescape(config_file), 
      vim.fn.shellescape(tmp_file), 
      vim.fn.shellescape(tmp_file), 
      vim.fn.shellescape(config_file)
    )
    vim.fn.system(cmd)
  end

  return true, config_file
end

function M.ensure_config(opts)
  opts = opts or {}
  local root = doodba.find_root()
  if not root then return nil end
  
  local config_file = root .. "/pyrightconfig.json"
  if vim.fn.filereadable(config_file) == 1 and not opts.force_regenerate then
    -- Check for legacy absolute paths
    local content = table.concat(vim.fn.readfile(config_file), "\n")
    local ok, json = pcall(vim.json.decode, content)
    local has_absolute = false
    
    if ok and json and json.executionEnvironments then
      for _, env in ipairs(json.executionEnvironments) do
        if env.root and env.root:sub(1, 1) == "/" then
          has_absolute = true
          break
        end
        if env.extraPaths then
          for _, p in ipairs(env.extraPaths) do
            if p:sub(1, 1) == "/" then
              has_absolute = true
              break
            end
          end
        end
        if has_absolute then break end
      end
    end

    if has_absolute then
      vim.notify("odoo-ide: Detected legacy absolute paths in pyrightconfig.json. Regenerating...", vim.log.levels.WARN)
      opts.force_regenerate = true
    else
      return config_file
    end
  end
  
  local success, result = M.write_config(opts)
  if success then
    return result
  end
  
  return nil
end

function M.setup_commands()
  vim.api.nvim_create_user_command("OdooGeneratePyrightConfig", function(cmd_opts)
    local opts = {
      force_regenerate = cmd_opts.bang,
      include_all_repos = cmd_opts.args:match("all") ~= nil,
    }

    local success, result = M.write_config(opts)
    if success then
      if result:match("already exists") then
        vim.notify("odoo-ide: " .. result, vim.log.levels.INFO)
      else
        vim.notify("odoo-ide: Generated " .. result, vim.log.levels.INFO)
      end
    else
      vim.notify("odoo-ide: " .. result, vim.log.levels.ERROR)
    end
  end, {
    bang = true,
    nargs = "?",
    desc = "Generate pyrightconfig.json for current Doodba project",
  })
end

return M
