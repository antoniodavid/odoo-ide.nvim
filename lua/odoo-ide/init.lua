local M = {}
local config = require("odoo-ide.config")

M.options = {}
M.context = nil
M.snippets = nil
M.lsp = nil
M.odools = nil

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", config.defaults, opts or {})

  M.context = require("odoo-ide.context")

  if M.options.snippets.enabled then
    local ok, snippets = pcall(require, "odoo-ide.snippets")
    if ok then
      M.snippets = snippets
      snippets.setup(M.options.snippets)
    else
      vim.notify("odoo-ide: LuaSnip not available, snippets disabled", vim.log.levels.WARN)
    end
  end

  if M.options.lsp.enabled then
    local ok, lsp = pcall(require, "odoo-ide.lsp")
    if ok then
      M.lsp = lsp
      lsp.setup(M.options)
    end
  end

  if M.options.dap.enabled then
    local ok_dap, dap = pcall(require, "odoo-ide.dap")
    if ok_dap then
      dap.setup(M.options)
    end
  end

  local ok_odools, odools = pcall(require, "odoo-ide.odools")
  if ok_odools then
    M.odools = odools
    odools.setup_commands()
  end

  local ok_pyright, pyright = pcall(require, "odoo-ide.pyright")
  if ok_pyright then
    pyright.setup_commands()
  end

  local ok_ruff, ruff = pcall(require, "odoo-ide.ruff")
  if ok_ruff then
    ruff.setup(M.options)
  end

  local ok_tasks, tasks = pcall(require, "odoo-ide.tasks")
  if ok_tasks then
    tasks.setup(M.options)
    tasks.setup_commands()
  end

  M.setup_commands()
end

function M.setup_commands()
  vim.api.nvim_create_user_command("OdooHelp", function()
    require("odoo-ide.ui").show_help()
  end, {
    desc = "Show the odoo-ide quick reference",
  })
end

function M.debug()
  if M.context then
    vim.print(M.context.get_context())
  else
    vim.notify("odoo-ide: Context module not loaded", vim.log.levels.WARN)
  end
end

function M.generate_odools_config(opts)
  if not M.odools then
    vim.notify("odoo-ide: odools module not loaded", vim.log.levels.ERROR)
    return
  end

  local success, result = M.odools.write_config(opts or {})
  if success then
    vim.notify("odoo-ide: Generated odools.toml at " .. result, vim.log.levels.INFO)
  else
    vim.notify("odoo-ide: Failed to generate odools.toml: " .. result, vim.log.levels.ERROR)
  end
end

function M.show_odools_config()
  if not M.odools then
    vim.notify("odoo-ide: odools module not loaded", vim.log.levels.ERROR)
    return
  end

  local content, err = M.odools.generate_config({
    profile_name = M.options.lsp.odoo_ls.profile_name,
    python_path = M.options.lsp.odoo_ls.python_path,
    additional_stubs = M.options.lsp.odoo_ls.additional_stubs,
  })

  if content then
    vim.notify("odools.toml content:\n" .. content, vim.log.levels.INFO)
  else
    vim.notify("odoo-ide: " .. (err or "Failed to generate config"), vim.log.levels.ERROR)
  end
end

return M