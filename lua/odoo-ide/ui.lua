local M = {}
local api = vim.api

function M.show_help()
  local buf = api.nvim_create_buf(false, true)
  local width = math.min(100, vim.o.columns - 4)
  local height = math.min(40, vim.o.lines - 4)

  local opts = {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
    title = " Odoo IDE - Quick Start ",
    title_pos = "center",
  }

  local help_text = {
    " # Welcome to odoo-ide.nvim ",
    "",
    " ## 1. What is active",
    "    - [x] Project detection: Doodba, local checkouts, addon repositories",
    "    - [x] odoo-ls (completion, definition, hover, diagnostics)",
    "    - [x] Snippets (try 'oomodel', 'oofcompute', 'oovtree')",
    "    - [x] Ruff formatting and linting (conform.nvim / nvim-lint)",
    "    - [x] DAP debugging for Doodba containers (nvim-dap)",
    "",
    " ## 2. Project configuration",
    "    :OdooGenerateConfig      -> generate odools.toml",
    "    :OdooShowConfig          -> preview the generated odools.toml",
    "    :OdooGeneratePyrightConfig -> generate pyrightconfig.json",
    "    :lua vim.print(require('odoo-ide.project').get())",
    "",
    " ## 3. How to debug (Python, Doodba)",
    "    1. :OdooDebug        -> Start container + attach debugger",
    "    2. :OdooStartDebug   -> Start container with debugpy only",
    "    3. <leader>dD        -> One-step debug start + attach",
    "    4. Set Breakpoint:   <leader>db",
    "",
    " ## 4. Tasks (Doodba)",
    "    - :OdooTest              -> Run tests in a terminal buffer",
    "    - :OdooLogs              -> Follow the container logs",
    "    - :OdooStart/Stop/Restart",
    "    - :OdooInstall / :OdooUninstall / :OdooResetDB",
    "    - :OdooScaffold module_name=my_module",
    "",
    " ## 5. Checks",
    "    - :checkhealth vim.lsp   -> Attached language servers",
    "    - :LuaSnipListAvailable  -> Loaded snippet triggers",
    "",
    " Press <q> or <Esc> to close",
  }

  api.nvim_buf_set_lines(buf, 0, -1, false, help_text)

  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = false

  api.nvim_open_win(buf, true, opts)

  vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, noremap = true, silent = true })
  vim.keymap.set("n", "<Esc>", "<cmd>close<CR>", { buffer = buf, noremap = true, silent = true })
end

return M
