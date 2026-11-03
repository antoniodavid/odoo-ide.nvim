local M = {}
local doodba = require("odoo-ide.doodba")
local tasks = require("odoo-ide.tasks")

local function get_odoo_version(root)
  local common_yaml = root .. "/common.yaml"
  local f = io.open(common_yaml, "r")
  if not f then return 17.0 end

  local content = f:read("*a")
  f:close()

  local version_str = content:match('ODOO_VERSION:%s*["\']?([%d%.]+)["\']?')
  if version_str then
    return tonumber(version_str)
  end
  return 17.0
end

local function get_debugpy_port(root)
  return math.floor(get_odoo_version(root)) * 1000 + 899
end

local function get_path_mappings(root, version)
  local mappings = {}
  local src_path = root .. "/odoo/custom/src"

  table.insert(mappings, {
    localRoot = src_path .. "/odoo",
    remoteRoot = "/opt/odoo/custom/src/odoo"
  })

  local handle = vim.loop.fs_scandir(src_path)
  if handle then
    while true do
      local name, type = vim.loop.fs_scandir_next(handle)
      if not name then break end

      if type == "directory" and name ~= "odoo" then
        local repo_path = src_path .. "/" .. name

        local answers = io.open(repo_path .. "/.copier-answers.yml", "r")
        if answers then
          local content = answers:read("*a")
          answers:close()
        end

        local addons_handle = vim.loop.fs_scandir(repo_path)
        if addons_handle then

           local function scan_dir(dir, relative_prefix)
              local h = vim.loop.fs_scandir(dir)
              if not h then return end
              while true do
                local addon_name, addon_type = vim.loop.fs_scandir_next(h)
                if not addon_name then break end

                if addon_type == "directory" then
                   local addon_full_path = dir .. "/" .. addon_name
                   local manifest = io.open(addon_full_path .. "/__manifest__.py", "r") or io.open(addon_full_path .. "/__openerp__.py", "r")
                   if manifest then
                      manifest:close()
                      local remote_root = "/opt/odoo/auto/addons/" .. addon_name
                      table.insert(mappings, {
                        localRoot = addon_full_path,
                        remoteRoot = remote_root
                      })
                   end
                end
              end
           end

           scan_dir(repo_path)
           scan_dir(repo_path .. "/addons")
           scan_dir(repo_path .. "/odoo/custom/src/private")
        end
      end
    end
  end

  return mappings
end

local function wait_for_port(port, timeout_sec, callback)
  local elapsed = 0
  local timer = vim.loop.new_timer()
  timer:start(0, 1000, vim.schedule_wrap(function()
    if elapsed >= timeout_sec then
      timer:close()
      callback(false, "Timeout waiting for port " .. port)
      return
    end

    local check = io.popen("ss -tlnp 'sport = :" .. port .. "' 2>/dev/null || nc -z 127.0.0.1 " .. port .. " 2>/dev/null")
    if check then
      local result = check:read("*a")
      check:close()
      if result and #result > 0 then
        timer:close()
        callback(true)
        return
      end
    end

    elapsed = elapsed + 1
    if elapsed % 5 == 0 then
      vim.notify("[odoo-ide] Waiting for debugpy on :" .. port .. " (" .. elapsed .. "s)", vim.log.levels.INFO)
    end
  end))
end

function M.setup(opts)
  local dap_ok, dap = pcall(require, "dap")
  if not dap_ok then return end

  if not doodba.is_doodba() then return end

  M.options = opts or {}
  local root = doodba.find_root()
  local port = get_debugpy_port(root)

  dap.adapters.python = {
    type = "server",
    host = "127.0.0.1",
    port = port,
  }

  local path_mappings = get_path_mappings(root, get_odoo_version(root))

  dap.configurations.python = {
    {
      type = "python",
      request = "attach",
      name = "Odoo: Attach to Container (Port " .. port .. ")",
      host = "127.0.0.1",
      port = port,
      pathMappings = path_mappings,
      justMyCode = false,
    }
  }

  vim.schedule(function()
    vim.notify("DAP: Odoo Python Debugger configured on 127.0.0.1:" .. port, vim.log.levels.INFO)
  end)

  local web_port = math.floor(get_odoo_version(root)) * 1000 + 69
  local web_url = "http://localhost:" .. web_port .. "/?debug=assets"

  dap.configurations.javascript = {
    {
        type = "pwa-chrome",
        request = "attach",
        name = "Odoo: Attach Chrome (Port 9222)",
        port = 9222,
        urlFilter = web_url .. "*",
        webRoot = "${workspaceFolder}",
    }
  }

  M.register_commands()
  M.register_keymaps()
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
  local dap_ok, _ = pcall(require, "dap")
  if not dap_ok then return end

  vim.api.nvim_set_keymap("n", "<leader>dD", "", {
    noremap = true,
    desc = "Odoo: Debug start + attach",
    callback = function()
      M.attach_and_debug()
    end,
  })
end

function M.start_debug()
  local root = doodba.find_root()
  if not root then
    vim.notify("[odoo-ide] Not in a Doodba project", vim.log.levels.ERROR)
    return
  end

  local port = get_debugpy_port(root)
  local odoo_version = get_odoo_version(root)

  tasks.start_debug({
    odoo_version = odoo_version,
  })
end

function M.attach_and_debug()
  local dap_ok, dap = pcall(require, "dap")
  if not dap_ok then
    vim.notify("[odoo-ide] nvim-dap not installed", vim.log.levels.ERROR)
    return
  end

  local root = doodba.find_root()
  if not root then
    vim.notify("[odoo-ide] Not in a Doodba project", vim.log.levels.ERROR)
    return
  end

  local port = get_debugpy_port(root)
  local odoo_version = get_odoo_version(root)

  -- Probe if container already running with debugpy
  local check = io.popen("ss -tlnp 'sport = :" .. port .. "' 2>/dev/null")
  local already_running = false
  if check then
    local result = check:read("*a")
    check:close()
    already_running = result and #result > 0
  end

  if not already_running then
    vim.notify("[odoo-ide] Starting Odoo with debugpy on :" .. port .. "...", vim.log.levels.INFO)
    tasks.start_debug({
      odoo_version = odoo_version,
    })

    wait_for_port(port, 30, function(success, err)
      if not success then
        vim.notify("[odoo-ide] Debug attach failed: " .. (err or "port not available"), vim.log.levels.ERROR)
        return
      end

      vim.schedule(function()
        vim.notify("[odoo-ide] Container ready, attaching debugger...", vim.log.levels.INFO)
        local dapui_ok, dapui = pcall(require, "dapui")
        if dapui_ok then
          dapui.open()
        end
        dap.continue()
      end)
    end)
  else
    vim.notify("[odoo-ide] Attaching to running Odoo on :" .. port, vim.log.levels.INFO)
    local dapui_ok, dapui = pcall(require, "dapui")
    if dapui_ok then
      dapui.open()
    end
    dap.continue()
  end
end

function M.generate_launch_json()
end

return M
