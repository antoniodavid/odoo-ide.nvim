local M = {}

M.defaults = {
  doodba_aware = true,
  snippets = {
    enabled = true,
    python = true,
    xml = true,
    js = true,
  },
  lsp = {
    enabled = true,
    auto_configure = true,
    -- Extra LSP capabilities merged over Neovim's defaults, e.g.
    -- require("blink.cmp").get_lsp_capabilities()
    capabilities = nil,
    -- Configure pyright/basedpyright path injection
    -- Disabled by default - use odoo_ls instead for Odoo projects
    pyright = {
      enabled = false,
      -- Python version advertised to pyright
      python_version = "3.10",
    },
    -- Configure odoo-ls (official Odoo Language Server)
    odoo_ls = {
      enabled = true,
      -- Auto-generate odools.toml for Doodba projects
      auto_config = true,
      -- Profile name for odools.toml
      profile_name = "main",
      -- Path to odoo_ls_server binary (auto-detected if nil)
      cmd = nil,
      -- Path to python typeshed stdlib (auto-detected if nil)
      stdlib_path = nil,
      -- Additional stubs paths
      additional_stubs = {},
      -- Python executable path (nil = system python)
      python_path = nil,
    },
  },
  -- Ruff configuration (formatter and linter)
  ruff = {
    enabled = true,
    -- Format method: "ruff" (ruff format) or "ruff_format" (ruff format)
    format = "ruff_format",
    -- Additional args for formatter
    format_args = {},
    -- Linter method: "ruff" (ruff check)
    lint = "ruff",
    -- Additional args for linter
    lint_args = {},
    -- Run nvim-lint on every buffer write
    lint_on_save = false,
  },
  -- DAP / Debugging configuration
  dap = {
    enabled = true,
    -- "auto" calcula desde ODOO_VERSION: math.floor(ver) * 1000 + 899
    debugpy_port = "auto",
    -- Bind <leader>dD to start + attach
    keymap = true,
  },
  -- odools.toml generation options
  odools = {
    -- Output path relative to project root (nil = project root)
    output_path = nil,
  },
}

return M
