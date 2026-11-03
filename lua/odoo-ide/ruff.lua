local M = {}

local function has_ruff()
  return vim.fn.executable("ruff") == 1
end

function M.setup(opts)
  opts = opts or {}
  local ruff_opts = opts.ruff or {}

  if not has_ruff() then
    vim.notify("odoo-ide: ruff not found in PATH, ruff integration disabled", vim.log.levels.WARN)
    return
  end

  if ruff_opts.enabled == false then
    return
  end

  M.setup_formatter(ruff_opts)
  M.setup_linter(ruff_opts)
end

function M.setup_formatter(opts)
  local ok, conform = pcall(require, "conform")
  if not ok then
    vim.notify("odoo-ide: conform.nvim not found, ruff formatter disabled", vim.log.levels.WARN)
    return
  end

  conform.formatters_by_ft = conform.formatters_by_ft or {}
  conform.formatters_by_ft.python = conform.formatters_by_ft.python or {}

  if opts.format == "ruff" then
    table.insert(conform.formatters_by_ft.python, "ruff")
  elseif opts.format == "ruff_format" then
    table.insert(conform.formatters_by_ft.python, "ruff_format")
  end

  conform.formatters.ruff = {
    condition = function(ctx)
      return has_ruff()
    end,
    prepend_args = opts.format_args or {},
  }

  conform.formatters.ruff_format = {
    condition = function(ctx)
      return has_ruff()
    end,
    prepend_args = opts.format_args or {},
  }
end

function M.setup_linter(opts)
  local ok, lint = pcall(require, "lint")
  if not ok then
    vim.notify("odoo-ide: nvim-lint not found, ruff linter disabled", vim.log.levels.WARN)
    return
  end

  lint.linters_by_ft = lint.linters_by_ft or {}
  lint.linters_by_ft.python = lint.linters_by_ft.python or {}

  if opts.lint == "ruff" then
    table.insert(lint.linters_by_ft.python, "ruff")
  end

  lint.linters.ruff = {
    cmd = "ruff",
    args = {
      "check",
      "--output-format=json",
      "--stdin-filename",
      "%:p",
      "-",
    },
    stdin = true,
    stream = "stdout",
    ignore_exitcode = true,
    parser = function(output, bufnr)
      local diagnostics = {}
      local ok, decoded = pcall(vim.json.decode, output)

      if not ok or not decoded then
        return diagnostics
      end

      for _, item in ipairs(decoded or {}) do
        table.insert(diagnostics, {
          lnum = item.location.row - 1,
          col = item.location.column - 1,
          end_lnum = item.end_location.row - 1,
          end_col = item.end_location.column - 1,
          severity = item.fix and vim.diagnostic.severity.WARN or vim.diagnostic.severity.ERROR,
          message = item.message,
          source = "ruff",
          code = item.code,
        })
      end

      return diagnostics
    end,
  }

  local opts_lint_args = opts.lint_args or {}
  if #opts_lint_args > 0 then
    lint.linters.ruff.args = vim.list_extend(lint.linters.ruff.args, opts_lint_args)
  end
end

return M
