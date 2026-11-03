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
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = "minimal",
    border = "rounded",
    title = " Odoo IDE - Quick Start ",
    title_pos = "center"
  }

  local help_text = {
    " # Welcome to odoo-ide.nvim ",
    "",
    " ## 1. Features Active",
    "    - [x] Odoo-LS Integration (Autocompletion, Go-to-Definition)",
    "    - [x] Pyright / BasedPyright Configuration (Auto-paths)",
    "    - [x] Snippets (Try typing 'oomodel', 'oofield')",
    "    - [x] DAP Debugging (Auto-configured for Doodba)",
    "",
    " ## 2. How to Debug (Python)",
    "    1. :OdooDebug        -> Start container + attach debugger",
    "    2. :OdooStartDebug   -> Start container with debugpy only",
    "    3. <leader>dD        -> One-step debug start + attach",
    "    4. Set Breakpoint:   <leader>db",
    "    5. Manual:           :DapContinue -> Select 'Odoo: Attach'",
    "",
    " ## 3. Linting (Ruff)",
    "    - The plugin relies on standard 'ruff.toml' or 'pyproject.toml'.",
    "    - Doodba/OCA repos usually include these files.",
    "    - Ensure 'nvim-lint' or 'none-ls' is installed in your config.",
    "",
    " ## 4. Useful Commands",
    "    - :OdooHelp               -> Show this window",
    "    - :OdooDebug              -> Start Odoo + attach debugger",
    "    - :OdooStartDebug         -> Start Odoo with debugpy only",
    "    - :OdooStart/Stop/Restart -> Docker compose lifecycle",
    "    - :OdooTest               -> Run test for current module",
    "    - :OdooLogs               -> Show Docker logs",
    "    - :LspInfo                -> Check attached servers",
    "    - :LuaSnipListAvailable   -> Check snippets",
    "",
    " Press <q> or <Esc> to close"
  }

  api.nvim_buf_set_lines(buf, 0, -1, false, help_text)
  
  api.nvim_buf_set_option(buf, "filetype", "markdown")
  api.nvim_buf_set_option(buf, "modifiable", false)

  local win = api.nvim_open_win(buf, true, opts)

  local close_cmd = "<cmd>close<CR>"
  api.nvim_buf_set_keymap(buf, "n", "q", close_cmd, { noremap = true, silent = true })
  api.nvim_buf_set_keymap(buf, "n", "<Esc>", close_cmd, { noremap = true, silent = true })
end

return M
