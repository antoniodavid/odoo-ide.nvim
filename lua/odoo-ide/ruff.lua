local M = {}

local function has_ruff()
  return vim.fn.executable("ruff") == 1
end

---Add a formatter/linter name to a conform or nvim-lint "by filetype" value.
---
---Both plugins accept either a list or a function returning a list; wrapping
---the function avoids the crash a plain `table.insert` produced.
---@param target table|function|nil
---@param name string
---@return table|function
function M.append_name(target, name)
  if type(target) == "function" then
    return function(bufnr)
      local list = target(bufnr) or {}
      if not vim.tbl_contains(list, name) then
        table.insert(list, name)
      end
      return list
    end
  end

  local list = target or {}
  if not vim.tbl_contains(list, name) then
    table.insert(list, name)
  end
  return list
end

---Build the ruff linter arguments.
---
---Ruff reads the buffer from stdin, so the `-` marker must be the last
---argument; anything after it is parsed as a file path.
---@param opts table ruff options
---@return string[]
function M.build_args(opts)
  local args = { "check", "--output-format=json", "--stdin-filename", "%:p" }

  for _, extra in ipairs(opts.lint_args or {}) do
    table.insert(args, extra)
  end

  table.insert(args, "-")
  return args
end

---Diagnostic severity for a ruff rule code.
---@param code string|nil
---@return integer
function M.severity(code)
  local prefix = (code or ""):sub(1, 1)
  if prefix == "E" or prefix == "F" then
    return vim.diagnostic.severity.ERROR
  end

  return vim.diagnostic.severity.WARN
end

---Parse ruff JSON output into nvim-lint diagnostics.
---@param output string
---@return table[]
function M.parse(output)
  local diagnostics = {}

  local ok, decoded = pcall(vim.json.decode, output)
  if not ok or type(decoded) ~= "table" then
    return diagnostics
  end

  for _, item in ipairs(decoded) do
    local location = item.location or {}
    local end_location = item.end_location or location
    local row = location.row or 1
    local column = location.column or 1

    table.insert(diagnostics, {
      lnum = row - 1,
      col = column - 1,
      end_lnum = (end_location.row or row) - 1,
      end_col = (end_location.column or column) - 1,
      severity = M.severity(item.code),
      message = item.message or "ruff",
      source = "ruff",
      code = item.code,
    })
  end

  return diagnostics
end

---Configure conform.nvim to format Python with ruff.
---@param opts table ruff options
---@return boolean configured
function M.setup_formatter(opts)
  local ok, conform = pcall(require, "conform")
  if not ok then
    return false
  end

  local name = opts.format == "ruff" and "ruff" or "ruff_format"

  conform.formatters_by_ft = conform.formatters_by_ft or {}
  conform.formatters_by_ft.python = M.append_name(conform.formatters_by_ft.python, name)

  -- Keep whatever the user configured for this formatter; only fill the gaps.
  local formatter = conform.formatters[name] or {}
  formatter.condition = formatter.condition or function()
    return has_ruff()
  end
  if formatter.prepend_args == nil and opts.format_args and #opts.format_args > 0 then
    formatter.prepend_args = opts.format_args
  end
  conform.formatters[name] = formatter

  return true
end

---Configure nvim-lint to lint Python with ruff.
---@param opts table ruff options
---@return boolean configured
function M.setup_linter(opts)
  local ok, lint = pcall(require, "lint")
  if not ok then
    return false
  end

  lint.linters_by_ft = lint.linters_by_ft or {}
  if opts.lint == "ruff" then
    lint.linters_by_ft.python = M.append_name(lint.linters_by_ft.python, "ruff")
  end

  local linter = lint.linters.ruff or {}
  linter.cmd = linter.cmd or "ruff"
  linter.args = linter.args or M.build_args(opts)
  linter.stdin = linter.stdin ~= nil and linter.stdin or true
  linter.stream = linter.stream or "stdout"
  linter.ignore_exitcode = linter.ignore_exitcode ~= nil and linter.ignore_exitcode or true
  linter.parser = linter.parser or M.parse
  lint.linters.ruff = linter

  if opts.lint_on_save then
    vim.api.nvim_create_autocmd("BufWritePost", {
      callback = function()
        require("lint").try_lint()
      end,
    })
  end

  return true
end

function M.setup(opts)
  opts = opts or {}
  local ruff_opts = opts.ruff or {}

  if ruff_opts.enabled == false then
    return
  end

  if not has_ruff() then
    vim.notify("odoo-ide: ruff not found in PATH, ruff integration disabled", vim.log.levels.WARN)
    return
  end

  if not M.setup_formatter(ruff_opts) then
    vim.notify("odoo-ide: conform.nvim not found, ruff formatter disabled", vim.log.levels.WARN)
  end

  if not M.setup_linter(ruff_opts) then
    vim.notify("odoo-ide: nvim-lint not found, ruff linter disabled", vim.log.levels.WARN)
  end
end

return M
