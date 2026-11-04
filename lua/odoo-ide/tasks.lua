local M = {}
local doodba = require("odoo-ide.doodba")
local context = require("odoo-ide.context")

---Defaults for the Docker service and database names (Doodba conventions).
local DEFAULTS = {
  dbname = "devel",
  service = "odoo",
  proxy_service = "odoo_proxy",
}

M.options = vim.deepcopy(DEFAULTS)

---Apply user options.
---@param opts table|nil plugin options
function M.setup(opts)
  local task_opts = (opts or {}).tasks or {}
  M.options = vim.tbl_extend("force", DEFAULTS, task_opts)
end

local function get_current_addon()
  local addon_root = context.get_addon_root()
  if addon_root then
    return addon_root:gsub(".*/", ""), addon_root
  end
  return nil, nil
end

local function find_project_root()
  return doodba.find_root()
end

---Run a command in a terminal buffer so its output is visible.
---@param root string Working directory
---@param cmd string[]
---@param title string Buffer name for the terminal
---@param on_exit? fun(code: integer)
---@return integer job id
function M.run_in_terminal(root, cmd, title, on_exit)
  vim.cmd("botright new")

  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "odoo-terminal"

  local job = vim.fn.jobstart(cmd, {
    cwd = root,
    term = true,
    on_exit = function(_, code)
      if on_exit then
        on_exit(code)
      end
    end,
  })

  pcall(vim.api.nvim_buf_set_name, buf, title)
  vim.cmd("startinsert")

  return job
end

function M.test(opts)
  opts = opts or {}
  local root = find_project_root()
  if not root then
    vim.notify("[odoo-ide] Not in a Doodba project", vim.log.levels.ERROR)
    return
  end

  local addon_name = opts.module
  local addon_path = opts.path

  if not addon_name and not addon_path then
    local name, path = get_current_addon()
    if name then
      addon_name = name
      addon_path = path
    end
  end

  if not addon_name then
    vim.notify("[odoo-ide] Cannot determine module. Use --module or be in a module directory.", vim.log.levels.ERROR)
    return
  end

  local cmd = {
    "docker",
    "compose",
    "run",
    "--rm",
    "-e", "DB_FILTER=^" .. M.options.dbname .. "$",
    M.options.service,
    "odoo",
    "--test-enable",
    "--stop-after-init",
    "--workers=0",
    "--test-tags",
    "/" .. addon_name,
    "-i",
    addon_name,
  }

  M.run_in_terminal(root, cmd, "odoo-ide test: " .. addon_name, function(code)
    if code == 0 then
      vim.notify("[odoo-ide] Tests passed for " .. addon_name, vim.log.levels.INFO)
    else
      vim.notify("[odoo-ide] Tests failed for " .. addon_name .. " (exit " .. code .. ")", vim.log.levels.ERROR)
    end
  end)
end

function M.install(opts)
  opts = opts or {}
  local root = find_project_root()
  if not root then
    vim.notify("[odoo-ide] Not in a Doodba project", vim.log.levels.ERROR)
    return
  end

  local addon_name = opts.module
  if not addon_name then
    local name = get_current_addon()
    if name then
      addon_name = name
    end
  end

  if not addon_name then
    vim.notify("[odoo-ide] Cannot determine module. Use --module or be in a module directory.", vim.log.levels.ERROR)
    return
  end

  local cmd = {
    "docker",
    "compose",
    "stop",
    M.options.service,
  }

  vim.system(cmd, { cwd = root }, function()
    local install_cmd = {
      "docker",
      "compose",
      "run",
      "--rm",
      M.options.service,
      "addons",
      "init",
      "-w",
      addon_name,
    }

    vim.system(install_cmd, { cwd = root }, function(handler)
      if handler.code == 0 then
        vim.notify("[odoo-ide] Module " .. addon_name .. " installed", vim.log.levels.INFO)
      else
        vim.notify("[odoo-ide] Failed to install " .. addon_name, vim.log.levels.ERROR)
      end
    end)
  end)
end

function M.uninstall(opts)
  opts = opts or {}
  local root = find_project_root()
  if not root then
    vim.notify("[odoo-ide] Not in a Doodba project", vim.log.levels.ERROR)
    return
  end

  local addon_name = opts.module
  if not addon_name then
    local name = get_current_addon()
    if name then
      addon_name = name
    end
  end

  if not addon_name then
    vim.notify("[odoo-ide] Cannot determine module. Use --module or be in a module directory.", vim.log.levels.ERROR)
    return
  end

  local cmd = {
    "docker",
    "compose",
    "run",
    "--rm",
    M.options.service,
    "click-odoo-uninstall",
    "-m",
    addon_name,
  }

  vim.system(cmd, { cwd = root }, function(handler)
    if handler.code == 0 then
      vim.notify("[odoo-ide] Module " .. addon_name .. " uninstalled", vim.log.levels.INFO)
    else
      vim.notify("[odoo-ide] Failed to uninstall " .. addon_name, vim.log.levels.ERROR)
    end
  end)
end

function M.logs(opts)
  opts = opts or {}
  local root = find_project_root()
  if not root then
    vim.notify("[odoo-ide] Not in a Doodba project", vim.log.levels.ERROR)
    return
  end

  local cmd = {
    "docker",
    "compose",
    "logs",
    "-f",
    "--tail",
    tostring(opts.tail or 50),
  }

  if opts.container then
    table.insert(cmd, opts.container)
  else
    table.insert(cmd, M.options.service)
  end

  M.run_in_terminal(root, cmd, "odoo-ide logs")
end

function M.start(opts)
  opts = opts or {}
  local root = find_project_root()
  if not root then
    vim.notify("[odoo-ide] Not in a Doodba project", vim.log.levels.ERROR)
    return
  end

  local cmd = {
    "docker",
    "compose",
    "up",
    "--detach",
  }

  vim.system(cmd, { cwd = root }, function(handler)
    if handler.code == 0 then
      vim.notify("[odoo-ide] Odoo started", vim.log.levels.INFO)
    else
      vim.notify("[odoo-ide] Failed to start Odoo", vim.log.levels.ERROR)
    end
  end)
end

function M.stop(opts)
  opts = opts or {}
  local root = find_project_root()
  if not root then
    vim.notify("[odoo-ide] Not in a Doodba project", vim.log.levels.ERROR)
    return
  end

  local cmd = {
    "docker",
    "compose",
    "down",
    "--remove-orphans",
  }

  vim.system(cmd, { cwd = root }, function(handler)
    if handler.code == 0 then
      vim.notify("[odoo-ide] Odoo stopped", vim.log.levels.INFO)
    else
      vim.notify("[odoo-ide] Failed to stop Odoo", vim.log.levels.ERROR)
    end
  end)
end

function M.restart(opts)
  opts = opts or {}
  local root = find_project_root()
  if not root then
    vim.notify("[odoo-ide] Not in a Doodba project", vim.log.levels.ERROR)
    return
  end

  local cmd = {
    "docker",
    "compose",
    "restart",
    "-t0",
    M.options.service,
    M.options.proxy_service,
  }

  vim.system(cmd, { cwd = root }, function(handler)
    if handler.code == 0 then
      vim.notify("[odoo-ide] Odoo restarted", vim.log.levels.INFO)
    else
      vim.notify("[odoo-ide] Failed to restart Odoo", vim.log.levels.ERROR)
    end
  end)
end

function M.resetdb(opts)
  opts = opts or {}
  local root = find_project_root()
  if not root then
    vim.notify("[odoo-ide] Not in a Doodba project", vim.log.levels.ERROR)
    return
  end

  local dbname = opts.dbname or M.options.dbname
  local modules = opts.modules or "base"

  local stop_cmd = { "docker", "compose", "stop", M.options.service }
  vim.system(stop_cmd, { cwd = root }, function()
    local drop_cmd = {
      "docker",
      "compose",
      "run",
      "--rm",
      "-l", "traefik.enable=false",
      M.options.service,
      "click-odoo-dropdb",
      dbname,
    }

    vim.system(drop_cmd, { cwd = root }, function()
      local init_cmd = {
        "docker",
        "compose",
        "run",
        "--rm",
        "-l", "traefik.enable=false",
        M.options.service,
        "click-odoo-initdb",
        "-n", dbname,
        "-m", modules,
      }

      vim.system(init_cmd, { cwd = root }, function(handler)
        if handler.code == 0 then
          vim.notify("[odoo-ide] Database " .. dbname .. " reset with " .. modules, vim.log.levels.INFO)
        else
          vim.notify("[odoo-ide] Failed to reset database", vim.log.levels.ERROR)
        end
      end)
    end)
  end)
end

---Map a host path to its location inside the scaffold container.
---
---The project root is mounted at `/tmp/project`, so an absolute path under the
---root must lose its prefix; otherwise the generated path resolves outside the
---mount and `odoo scaffold` fails.
---@param root string Absolute project root
---@param target string Absolute path under the root, or a project-relative path
---@return string|nil container_path
---@return string|nil err
function M.container_path(root, target)
  if not root or not target then
    return nil, "Missing project root or target path"
  end

  local normalized_root = vim.fs.normalize(root)
  local normalized_target = vim.fs.normalize(target)

  local prefix = normalized_root .. "/"
  if normalized_target:sub(1, #prefix) == prefix then
    return "/tmp/project/" .. normalized_target:sub(#prefix + 1)
  end

  if normalized_target:sub(1, 1) == "/" then
    return nil, "Target path is outside the project root: " .. normalized_target
  end

  return "/tmp/project/" .. normalized_target:gsub("^%./", "")
end

function M.scaffold(opts)
  opts = opts or {}
  local root = find_project_root()
  if not root then
    vim.notify("[odoo-ide] Not in a Doodba project", vim.log.levels.ERROR)
    return
  end

  local module_name = opts.module_name
  if not module_name then
    vim.notify("[odoo-ide] Module name required. Use --module-name", vim.log.levels.ERROR)
    return
  end

  local target_path = opts.path
  if not target_path then
    target_path = root .. "/odoo/custom/src/private"
  end

  local container_target, path_err = M.container_path(root, target_path)
  if not container_target then
    vim.notify("[odoo-ide] " .. path_err, vim.log.levels.ERROR)
    return
  end

  local cmd = {
    "docker",
    "compose",
    "run",
    "--rm",
    "-v",
    root .. ":/tmp/project:rw",
    M.options.service,
    "odoo",
    "scaffold",
    module_name,
    container_target,
  }

  vim.system(cmd, { cwd = root }, function(handler)
    if handler.code == 0 then
      vim.notify("[odoo-ide] Module " .. module_name .. " scaffolded at " .. target_path, vim.log.levels.INFO)
    else
      vim.notify("[odoo-ide] Failed to scaffold module", vim.log.levels.ERROR)
    end
  end)
end

function M.start_debug(opts)
  opts = opts or {}
  local root = find_project_root()
  if not root then
    vim.notify("[odoo-ide] Not in a Doodba project", vim.log.levels.ERROR)
    return nil
  end

  local port = opts.port

  -- Prefer invoke (standard Doodba)
  if vim.fn.executable("invoke") == 1 then
    local cmd = { "invoke", "start", "--detach", "--debugpy" }
    local handle = vim.system(cmd, { cwd = root, text = true, timeout = 120000 }, function(handler)
      if handler.code == 0 then
        vim.notify("[odoo-ide] Odoo started with debugpy on :" .. port, vim.log.levels.INFO)
      else
        local err = handler.stderr or ""
        local out = handler.stdout or ""
        vim.notify(
          "[odoo-ide] invoke start --debugpy failed (code=" .. handler.code .. ")\n"
            .. "stderr: " .. (err ~= "" and err or "(none)") .. "\n"
            .. "stdout: " .. (out ~= "" and out or "(none)"),
          vim.log.levels.ERROR
        )
      end
    end)
    return handle
  end

  -- Fallback: docker compose with ODOO_DEBUG + port mapping
  local cmd = {
    "docker", "compose", "up", "--detach",
    "--no-recreate",
  }

  local env = vim.deepcopy(vim.fn.environ())
  env["ODOO_DEBUG"] = "true"
  env["PYDEV_DEBUG"] = "true"

  local handle = vim.system(cmd, {
    cwd = root,
    env = env,
    text = true,
    timeout = 120000,
  }, function(handler)
    if handler.code == 0 then
      vim.notify("[odoo-ide] Odoo started. For debugpy, ensure compose exposes :" .. port, vim.log.levels.INFO)
    else
      local err = handler.stderr or ""
      local out = handler.stdout or ""
      vim.notify(
        "[odoo-ide] docker compose up failed (code=" .. handler.code .. ")\n"
          .. "stderr: " .. (err ~= "" and err or "(none)") .. "\n"
          .. "stdout: " .. (out ~= "" and out or "(none)"),
        vim.log.levels.ERROR
      )
    end
  end)

  return handle
end

function M.setup_commands()
  vim.api.nvim_create_user_command("OdooTest", function(cmd_opts)
    local opts = {}
    if cmd_opts.args and cmd_opts.args ~= "" then
      for key, value in cmd_opts.args:gmatch("(%w+)=([^%s]+)") do
        opts[key] = value
      end
    end
    M.test(opts)
  end, {
    nargs = "*",
    desc = "Run tests for current Odoo module",
  })

  vim.api.nvim_create_user_command("OdooInstall", function(cmd_opts)
    local opts = {}
    if cmd_opts.args and cmd_opts.args ~= "" then
      for key, value in cmd_opts.args:gmatch("(%w+)=([^%s]+)") do
        opts[key] = value
      end
    end
    M.install(opts)
  end, {
    nargs = "*",
    desc = "Install current Odoo module",
  })

  vim.api.nvim_create_user_command("OdooUninstall", function(cmd_opts)
    local opts = {}
    if cmd_opts.args and cmd_opts.args ~= "" then
      for key, value in cmd_opts.args:gmatch("(%w+)=([^%s]+)") do
        opts[key] = value
      end
    end
    M.uninstall(opts)
  end, {
    nargs = "*",
    desc = "Uninstall current Odoo module",
  })

  vim.api.nvim_create_user_command("OdooLogs", function(cmd_opts)
    local opts = { tail = 50 }
    if cmd_opts.args and cmd_opts.args ~= "" then
      local tail = cmd_opts.args:match("tail=(%d+)")
      if tail then
        opts.tail = tonumber(tail)
      end
    end
    M.logs(opts)
  end, {
    nargs = "?",
    desc = "Show Odoo logs",
  })

  vim.api.nvim_create_user_command("OdooStart", function()
    M.start()
  end, {
    desc = "Start Odoo environment",
  })

  vim.api.nvim_create_user_command("OdooStop", function()
    M.stop()
  end, {
    desc = "Stop Odoo environment",
  })

  vim.api.nvim_create_user_command("OdooRestart", function()
    M.restart()
  end, {
    desc = "Restart Odoo",
  })

  vim.api.nvim_create_user_command("OdooResetDB", function(cmd_opts)
    local opts = { dbname = nil, modules = "base" }
    if cmd_opts.args and cmd_opts.args ~= "" then
      local dbname = cmd_opts.args:match("dbname=([^%s]+)")
      local modules = cmd_opts.args:match("modules=([^%s]+)")
      if dbname then
        opts.dbname = dbname
      end
      if modules then
        opts.modules = modules
      end
    end
    M.resetdb(opts)
  end, {
    nargs = "?",
    desc = "Reset database",
  })

  vim.api.nvim_create_user_command("OdooScaffold", function(cmd_opts)
    local opts = {}
    if cmd_opts.args and cmd_opts.args ~= "" then
      local module_name = cmd_opts.args:match("module_name=([^%s]+)")
      local path = cmd_opts.args:match("path=([^%s]+)")
      if module_name then
        opts.module_name = module_name
      end
      if path then
        opts.path = path
      end
    end
    M.scaffold(opts)
  end, {
    nargs = "*",
    desc = "Scaffold a new Odoo module",
  })
end

return M