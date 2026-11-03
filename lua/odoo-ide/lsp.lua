local M = {}
local doodba = require("odoo-ide.doodba")

local function get_odoo_ls_cache_dir()
  local data_dir = vim.fn.expand("$HOME/.local/share/odoo-ls")
  return data_dir
end

local function validate_odoo_ls_cache(expected_odoo_path)
  local cache_dir = get_odoo_ls_cache_dir()
  local cache_file = cache_dir .. "/odoo_ls_cache.bin"

  if vim.fn.filereadable(cache_file) ~= 1 then
    return true
  end

  local file = io.open(cache_file, "rb")
  if not file then
    return true
  end

  local content = file:read(512)
  file:close()

  if not content then
    return true
  end

  local found_path = content:match("/[%w_/%-%.]+/odoo/custom/src/odoo")
  if not found_path then
    return true
  end

  if found_path ~= expected_odoo_path then
    return false, found_path
  end

  return true
end

local function clear_odoo_ls_cache()
  local cache_dir = get_odoo_ls_cache_dir()
  if vim.fn.isdirectory(cache_dir) == 1 then
    vim.fn.delete(cache_dir, "rf")
    return true
  end
  return false
end

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

function M.setup_pyright(opts)
  opts = opts or {}
  local pyright_opts = opts.pyright or {}

  if pyright_opts.enabled == false then
    return
  end

  -- For Doodba projects, we explicitly start pyright since there are no
  -- standard Python project markers (pyproject.toml, setup.py, etc.)
  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "python" },
    callback = function(ev)
      if not doodba.is_doodba() then
        return
      end

      local root = doodba.find_root()
      if not root then
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

      local pyright_binary = pyright_opts.cmd or find_pyright_binary()
      if not pyright_binary then
        vim.notify("[odoo-ide] pyright not found. Install via Mason or system package.", vim.log.levels.WARN)
        return
      end

      if pyright_opts.auto_config ~= false then
        local pyright_config = require("odoo-ide.pyright")
        pyright_config.ensure_config({
          force_regenerate = opts.pyright_config and opts.pyright_config.force_regenerate or false,
          output_path = opts.pyright_config and opts.pyright_config.output_path or nil,
        })
      end

      local paths = doodba.get_paths()
      local server_name = pyright_binary:match("basedpyright") and "basedpyright" or "pyright"

      vim.lsp.start({
        name = server_name,
        cmd = { pyright_binary, "--stdio" },
        root_dir = root,
        settings = {
          python = {
            analysis = {
              extraPaths = paths,
              autoSearchPaths = true,
              typeCheckingMode = pyright_opts.typeCheckingMode or "basic",
              diagnosticMode = pyright_opts.diagnosticMode or "openFilesOnly",
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

function M.setup_odoo_ls(opts)
  opts = opts or {}
  local odoo_ls_opts = opts.odoo_ls or {}
  local odools_opts = opts.odools or {}

  if odoo_ls_opts.enabled == false then
    return
  end

  local odoo_ls_binary = odoo_ls_opts.cmd or find_odoo_ls_binary()
  if not odoo_ls_binary then
    return
  end

  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "python", "xml", "csv", "javascript" },
    callback = function(ev)
      if not doodba.is_doodba() then
        return
      end

      local root = doodba.find_root()
      if not root then
        return
      end

      local bufnr = ev.buf
      local existing = vim.lsp.get_clients({ name = "odoo_ls", bufnr = bufnr })
      if #existing > 0 then
        return
      end

      if odoo_ls_opts.auto_config ~= false then
        local odools = require("odoo-ide.odools")
        local config_opts = {
          profile_name = odoo_ls_opts.profile_name or "main",
          python_path = odoo_ls_opts.python_path,
          additional_stubs = odoo_ls_opts.additional_stubs or {},
          force_regenerate = true,
          output_path = odools_opts.output_path,
        }
        odools.ensure_config(config_opts)
      end

      local expected_odoo_path = root .. "/odoo/custom/src/odoo"
      local cache_valid, cached_path = validate_odoo_ls_cache(expected_odoo_path)
      if not cache_valid then
        vim.notify(
          string.format("[odoo-ide] Cache mismatch detected. Clearing cache (was: %s, expected: %s)", 
            cached_path or "unknown", expected_odoo_path),
          vim.log.levels.WARN
        )
        clear_odoo_ls_cache()
      end

      local cmd = { odoo_ls_binary }
      local odools = require("odoo-ide.odools")
      local config_path = odools.get_config_path()

      if config_path then
        table.insert(cmd, "--config-path")
        table.insert(cmd, config_path)
      end

      local stdlib_path = odoo_ls_opts.stdlib_path or find_stdlib_path()
      if stdlib_path then
        table.insert(cmd, "--stdlib")
        table.insert(cmd, stdlib_path)
      end

      -- DEBUG: Log the command being executed
      vim.notify("[odoo-ide] Starting odoo_ls with cmd: " .. vim.inspect(cmd), vim.log.levels.DEBUG)

      vim.lsp.start({
        name = "odoo_ls",
        cmd = cmd,
        root_dir = root,
        workspace_folders = {
          {
            uri = vim.uri_from_fname(root),
            name = "main_folder",
          },
        },
        settings = {
          Odoo = {
            selectedProfile = odoo_ls_opts.profile_name or "main",
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

  if lsp_opts.pyright == nil or lsp_opts.pyright.enabled ~= false then
    M.setup_pyright(opts)
  end

  if lsp_opts.odoo_ls == nil or lsp_opts.odoo_ls.enabled ~= false then
    M.setup_odoo_ls({
      odoo_ls = lsp_opts.odoo_ls or {},
      odools = opts.odools or {},
    })
  end
end

function M.get_lsp_config()
  if not doodba.is_doodba() then
    return {}
  end

  local paths = doodba.get_paths()
  return {
    settings = {
      python = {
        analysis = {
          extraPaths = paths,
          autoSearchPaths = true,
          typeCheckingMode = "basic",
        },
      },
    },
  }
end

return M
