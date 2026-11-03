local M = {}
local project = require("odoo-ide.project")

local function find_odoo_ls_binary()
  local locations = {
    vim.fn.expand("$HOME/.local/share/nvim/odoo/odoo_ls_server"),
    "odoo_ls_server",
    vim.fn.expand("$HOME/.local/bin/odoo_ls_server"),
  }

  for _, location in ipairs(locations) do
    if vim.fn.executable(location) == 1 then
      return location
    end
  end
  return nil
end

local function find_stdlib_path()
  local odoo_ls_binary = find_odoo_ls_binary()
  if odoo_ls_binary then
    local binary_dir = vim.fn.fnamemodify(odoo_ls_binary, ":h")
    local stdlib_in_binary_dir = binary_dir .. "/stdlib"
    if vim.fn.isdirectory(stdlib_in_binary_dir) == 1 then
      return stdlib_in_binary_dir
    end
  end

  local typeshed_locations = {
    vim.fn.expand("$HOME/.local/share/nvim/odoo/typeshed/stdlib"),
    vim.fn.expand("$HOME/.local/share/typeshed/stdlib"),
    "/usr/share/typeshed/stdlib",
  }

  for _, location in ipairs(typeshed_locations) do
    if vim.fn.isdirectory(location) == 1 then
      return location
    end
  end

  return nil
end

local function find_pyright_binary()
  -- Check Mason installation first
  local mason_pyright = vim.fn.expand("$HOME/.local/share/nvim/mason/bin/pyright-langserver")
  if vim.fn.executable(mason_pyright) == 1 then
    return mason_pyright
  end

  -- Check for basedpyright in Mason
  local mason_basedpyright = vim.fn.expand("$HOME/.local/share/nvim/mason/bin/basedpyright-langserver")
  if vim.fn.executable(mason_basedpyright) == 1 then
    return mason_basedpyright
  end

  -- Fall back to system PATH
  if vim.fn.executable("pyright-langserver") == 1 then
    return "pyright-langserver"
  end

  if vim.fn.executable("basedpyright-langserver") == 1 then
    return "basedpyright-langserver"
  end

  return nil
end

---Configure pyright/basedpyright for Odoo projects.
---@param opts? table pyright options (lsp.pyright)
function M.setup_pyright(opts)
  opts = opts or {}

  if opts.enabled == false then
    return
  end

  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "python" },
    callback = function(ev)
      local current = project.get()
      if not current then
        return
      end

      local bufnr = ev.buf
      -- Check if pyright or basedpyright is already attached
      local existing = vim.lsp.get_clients({ bufnr = bufnr })
      for _, client in ipairs(existing) do
        if client.name == "pyright" or client.name == "basedpyright" then
          return
        end
      end

      local pyright_binary = opts.cmd or find_pyright_binary()
      if not pyright_binary then
        vim.notify("[odoo-ide] pyright not found. Install via Mason or system package.", vim.log.levels.WARN)
        return
      end

      if opts.auto_config ~= false then
        require("odoo-ide.pyright").ensure_config({ project = current })
      end

      local paths = project.paths(current)
      local server_name = pyright_binary:match("basedpyright") and "basedpyright" or "pyright"

      vim.lsp.start({
        name = server_name,
        cmd = { pyright_binary, "--stdio" },
        root_dir = current.root,
        settings = {
          python = {
            analysis = {
              extraPaths = paths,
              autoSearchPaths = true,
              typeCheckingMode = opts.typeCheckingMode or "basic",
              diagnosticMode = opts.diagnosticMode or "openFilesOnly",
              useLibraryCodeForTypes = true,
            },
          },
        },
      }, {
        bufnr = bufnr,
        reuse_client = function(client, config)
          return client.name == config.name and client.config.root_dir == config.root_dir
        end,
      })
    end,
  })
end

---Configure odoo-ls for the detected project.
---@param opts? table odoo_ls options (lsp.odoo_ls)
---@param odools_opts? table odools options
function M.setup_odoo_ls(opts, odools_opts)
  opts = opts or {}
  odools_opts = odools_opts or {}

  if opts.enabled == false then
    return
  end

  local odoo_ls_binary = opts.cmd or find_odoo_ls_binary()
  if not odoo_ls_binary then
    return
  end

  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "python", "xml", "csv", "javascript" },
    callback = function(ev)
      local current = project.get()
      if not current or not current.odoo_path then
        return
      end

      local bufnr = ev.buf
      local existing = vim.lsp.get_clients({ name = "odoo_ls", bufnr = bufnr })
      if #existing > 0 then
        return
      end

      local odools = require("odoo-ide.odools")

      -- Auto-generation is a Doodba convenience: there the environment root is
      -- the project. A local checkout is usually a clone of Odoo itself, so the
      -- server is left to auto-detect paths (or the user generates the file
      -- explicitly into the addon repository they work in).
      if opts.auto_config ~= false and project.is_doodba(current) then
        odools.ensure_config({
          project = current,
          profile_name = opts.profile_name or "main",
          python_path = opts.python_path,
          additional_stubs = opts.additional_stubs or {},
          output_path = odools_opts.output_path,
        })
      end

      local cmd = { odoo_ls_binary }
      local config_path = odools.get_config_path(current, { output_path = odools_opts.output_path })

      if config_path then
        table.insert(cmd, "--config-path")
        table.insert(cmd, config_path)
      end

      local stdlib_path = opts.stdlib_path or find_stdlib_path()
      if stdlib_path then
        table.insert(cmd, "--stdlib")
        table.insert(cmd, stdlib_path)
      end

      vim.notify("[odoo-ide] Starting odoo_ls with cmd: " .. vim.inspect(cmd), vim.log.levels.DEBUG)

      vim.lsp.start({
        name = "odoo_ls",
        cmd = cmd,
        root_dir = current.root,
        workspace_folders = {
          {
            uri = vim.uri_from_fname(current.root),
            name = "main_folder",
          },
        },
        settings = {
          Odoo = {
            selectedProfile = opts.profile_name or "main",
          },
        },
      }, {
        bufnr = bufnr,
        reuse_client = function(client, config)
          return client.name == config.name and client.config.root_dir == config.root_dir
        end,
      })
    end,
  })
end

function M.setup(opts)
  opts = opts or {}
  local lsp_opts = opts.lsp or {}

  if lsp_opts.enabled == false then
    return
  end

  M.setup_pyright(lsp_opts.pyright or {})
  M.setup_odoo_ls(lsp_opts.odoo_ls or {}, opts.odools or {})
end

return M
