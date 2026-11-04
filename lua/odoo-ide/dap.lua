local M = {}

local project = require("odoo-ide.project")
local tasks = require("odoo-ide.tasks")

---Adapter name used by this plugin, so a user's `python` adapter is untouched.
M.ADAPTER = "odoo-python"

M._configured = nil

---debugpy port for an Odoo version, matching Doodba's convention.
---@param odoo_version number|nil
---@return number
function M.debugpy_port(odoo_version)
  return math.floor(odoo_version or 17) * 1000 + 899
end

---Web port for an Odoo version.
---@param odoo_version number|nil
---@return number
function M.web_port(odoo_version)
  return math.floor(odoo_version or 17) * 1000 + 69
end

local function has_manifest(dir)
  return vim.fn.filereadable(dir .. "/__manifest__.py") == 1
    or vim.fn.filereadable(dir .. "/__openerp__.py") == 1
end

---Add every addon found directly inside `dir`.
---@param mappings table[]
---@param seen table<string, boolean>
---@param dir string
local function add_addons_from(mappings, seen, dir)
  if vim.fn.isdirectory(dir) == 0 then
    return
  end

  for name, kind in vim.fs.dir(dir) do
    if kind == "directory" and not seen[name] and has_manifest(dir .. "/" .. name) then
      seen[name] = true
      table.insert(mappings, {
        localRoot = dir .. "/" .. name,
        remoteRoot = "/opt/odoo/auto/addons/" .. name,
      })
    end
  end
end

---Path mappings for Doodba: the checkout root plus every addon, matching what
---Doodba's own `tasks.py` generates for VS Code.
---@param current table detected project
---@return table[]
function M.build_path_mappings(current)
  local mappings = {}

  if not current or not current.odoo_path then
    return mappings
  end

  local seen = {}
  local src = current.root .. "/odoo/custom/src"

  table.insert(mappings, {
    localRoot = current.odoo_path,
    remoteRoot = "/opt/odoo/custom/src/odoo",
  })

  -- Core addons, including the ones bundled inside the `odoo` package.
  add_addons_from(mappings, seen, current.odoo_path .. "/addons")
  add_addons_from(mappings, seen, current.odoo_path .. "/odoo/addons")

  -- Custom repositories, including the `private` folder.
  if vim.fn.isdirectory(src) == 1 then
    for name, kind in vim.fs.dir(src) do
      if kind == "directory" and name ~= "odoo" and name ~= "OCB" then
        local repo = src .. "/" .. name
        add_addons_from(mappings, seen, repo)
        add_addons_from(mappings, seen, repo .. "/addons")
      end
    end
  end

  return mappings
end

---Python debug configuration for the container.
---@param port number
---@param mappings table[]
---@return table
function M.build_python_configuration(port, mappings)
  return {
    type = M.ADAPTER,
    request = "attach",
    name = "Odoo: Attach to Container (Port " .. port .. ")",
    host = "127.0.0.1",
    port = port,
    pathMappings = mappings,
    justMyCode = false,
  }
end

---Browser debug configuration for the Odoo web client.
---@param odoo_version number|nil
---@return table
function M.build_javascript_configuration(odoo_version)
  return {
    type = "pwa-chrome",
    request = "attach",
    name = "Odoo: Attach Chrome (Port 9222)",
    port = 9222,
    urlFilter = "http://localhost:" .. M.web_port(odoo_version) .. "/?debug=assets*",
    webRoot = "${workspaceFolder}",
  }
end

---Register the adapter and configurations for the current Doodba project.
---
---Existing adapters and configurations are preserved: the plugin owns only the
---entries whose type is `odoo-python`.
---@return table|nil project
function M.ensure_configured()
  local dap_ok, dap = pcall(require, "dap")
  if not dap_ok then
    return nil
  end

  local current = project.get()
  if not current or not project.is_doodba(current) then
    return nil
  end

  local port = M.debugpy_port(current.version)
  local key = current.root .. "|" .. tostring(port)
  if M._configured == key then
    return current
  end

  dap.adapters[M.ADAPTER] = {
    type = "server",
    host = "127.0.0.1",
    port = port,
  }

  local python_configs = {}
  for _, config in ipairs(dap.configurations.python or {}) do
    if config.type ~= M.ADAPTER then
      table.insert(python_configs, config)
    end
  end
  table.insert(python_configs, M.build_python_configuration(port, M.build_path_mappings(current)))
  dap.configurations.python = python_configs

  -- Only offer the browser configuration when the adapter actually exists;
  -- registering it unconditionally produced a configuration that could not run.
  if dap.adapters["pwa-chrome"] then
    local js_config = M.build_javascript_configuration(current.version)
    local js_configs = {}
    for _, config in ipairs(dap.configurations.javascript or {}) do
      if config.name ~= js_config.name then
        table.insert(js_configs, config)
      end
    end
    table.insert(js_configs, js_config)
    dap.configurations.javascript = js_configs
  end

  M._configured = key
  return current
end

---Forget the configured project (used when the project changes in tests).
function M.reset()
  M._configured = nil
end

---Check whether a TCP port accepts connections, without blocking the UI.
---@param port number
---@param callback fun(open: boolean)
function M.port_open(port, callback)
  local uv = vim.uv
  local tcp = uv.new_tcp()
  if not tcp then
    return callback(false)
  end

  local finished = false
  tcp:connect("127.0.0.1", port, function(err)
    if finished then
      return
    end
    finished = true
    tcp:close()
    callback(err == nil)
  end)
end

---Poll a port until it accepts connections or the timeout expires.
---@param port number
---@param timeout_sec number
---@param callback fun(ok: boolean, err: string|nil)
function M.wait_for_port(port, timeout_sec, callback)
  local uv = vim.uv
  local timer = uv.new_timer()
  local elapsed = 0
  local checking = false

  timer:start(0, 1000, vim.schedule_wrap(function()
    if elapsed >= timeout_sec then
      timer:stop()
      timer:close()
      callback(false, "Timeout waiting for port " .. port)
      return
    end

    elapsed = elapsed + 1
    if checking then
      return
    end
    checking = true

    M.port_open(port, function(open)
      checking = false
      if open then
        timer:stop()
        timer:close()
        callback(true)
      elseif elapsed % 5 == 0 then
        vim.notify("[odoo-ide] Waiting for debugpy on :" .. port .. " (" .. elapsed .. "s)", vim.log.levels.INFO)
      end
    end)
  end))
end

function M.register_commands()
  vim.api.nvim_create_user_command("OdooDebug", function()
    M.attach_and_debug()
  end, {
    desc = "Start Odoo with debugpy and attach debugger",
  })

  vim.api.nvim_create_user_command("OdooStartDebug", function()
    M.start_debug()
  end, {
    desc = "Start Odoo container with debugpy (no attach)",
  })
end

function M.register_keymaps()
  vim.keymap.set("n", "<leader>dD", function()
    M.attach_and_debug()
  end, { desc = "Odoo: Debug start + attach" })
end

function M.setup(opts)
  local dap_ok = pcall(require, "dap")
  if not dap_ok then
    return
  end

  M.options = opts or {}
  M.register_commands()

  local dap_opts = M.options.dap or {}
  if dap_opts.keymap ~= false then
    M.register_keymaps()
  end

  -- Configure lazily: at startup the working directory is not necessarily the
  -- project the user will work on.
  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "python" },
    callback = function()
      M.ensure_configured()
    end,
  })

  vim.schedule(function()
    M.ensure_configured()
  end)
end

function M.start_debug()
  local current = M.ensure_configured()
  if not current then
    vim.notify("[odoo-ide] Not in a Doodba project", vim.log.levels.ERROR)
    return
  end

  tasks.start_debug({
    odoo_version = current.version or 17,
  })
end

function M.attach_and_debug()
  local dap_ok, dap = pcall(require, "dap")
  if not dap_ok then
    vim.notify("[odoo-ide] nvim-dap not installed", vim.log.levels.ERROR)
    return
  end

  local current = M.ensure_configured()
  if not current then
    vim.notify("[odoo-ide] Not in a Doodba project", vim.log.levels.ERROR)
    return
  end

  local port = M.debugpy_port(current.version)
  local mappings = M.build_path_mappings(current)

  local function attach()
    local dapui_ok, dapui = pcall(require, "dapui")
    if dapui_ok then
      dapui.open()
    end
    dap.run(M.build_python_configuration(port, mappings))
  end

  M.port_open(port, function(open)
    if open then
      vim.notify("[odoo-ide] Attaching to running Odoo on :" .. port, vim.log.levels.INFO)
      attach()
      return
    end

    vim.notify("[odoo-ide] Starting Odoo with debugpy on :" .. port .. "...", vim.log.levels.INFO)
    tasks.start_debug({
      odoo_version = current.version or 17,
    })

    M.wait_for_port(port, 30, function(success, err)
      if not success then
        vim.notify("[odoo-ide] Debug attach failed: " .. (err or "port not available"), vim.log.levels.ERROR)
        return
      end

      vim.schedule(function()
        vim.notify("[odoo-ide] Container ready, attaching debugger...", vim.log.levels.INFO)
        attach()
      end)
    end)
  end)
end

return M
