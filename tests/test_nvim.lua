-- Portable smoke tests for the public module surface.
--
-- Verifies that every module loads, that setup() runs outside a project, and
-- that the user-facing commands exist. Snippet assertions are skipped when
-- LuaSnip is not installed.
--
-- Run with: nvim --headless -u NONE -l tests/test_nvim.lua

local script = debug.getinfo(1, "S").source:sub(2)
local plugin_root = vim.fn.fnamemodify(script, ":p:h:h")
vim.opt.rtp:prepend(plugin_root)

local failures = 0

local function check(label, expected, actual)
  local ok = expected == actual
  print((ok and "PASS" or "FAIL") .. ": " .. label)
  if not ok then
    print("  expected: " .. vim.inspect(expected))
    print("  actual:   " .. vim.inspect(actual))
    failures = failures + 1
  end
end

local function check_true(label, condition, detail)
  print((condition and "PASS" or "FAIL") .. ": " .. label)
  if not condition then
    if detail then
      print("  detail: " .. vim.inspect(detail))
    end
    failures = failures + 1
  end
end

-- Modules that must always load without optional dependencies.
for _, name in ipairs({
  "odoo-ide",
  "odoo-ide.config",
  "odoo-ide.context",
  "odoo-ide.doodba",
  "odoo-ide.odools",
  "odoo-ide.pyright",
  "odoo-ide.tasks",
  "odoo-ide.lsp",
  "odoo-ide.dap",
  "odoo-ide.ui",
  "odoo-ide.utils",
}) do
  local ok, mod = pcall(require, name)
  check_true("module loads: " .. name, ok and type(mod) == "table", mod)
end

-- Snippets only load with LuaSnip present.
local luasnip_ok = pcall(require, "luasnip")
if luasnip_ok then
  local ok, mod = pcall(require, "odoo-ide.snippets")
  check_true("module loads: odoo-ide.snippets", ok and type(mod) == "table", mod)
else
  print("SKIP: odoo-ide.snippets (LuaSnip not available)")
end

-- setup() must not error outside a project nor start any server.
local odoo_ide = require("odoo-ide")
local ok, err = pcall(function()
  odoo_ide.setup({
    snippets = { enabled = false },
    lsp = { enabled = false },
    dap = { enabled = false },
    ruff = { enabled = false },
  })
end)
check("setup outside project", nil, ok and nil or err)

-- Commands registered by setup() and by the module entry point.
for _, command in ipairs({
  "OdooHelp",
  "OdooTest",
  "OdooInstall",
  "OdooUninstall",
  "OdooLogs",
  "OdooStart",
  "OdooStop",
  "OdooRestart",
  "OdooResetDB",
  "OdooScaffold",
  "OdooGenerateConfig",
  "OdooShowConfig",
  "OdooGeneratePyrightConfig",
}) do
  check("command exists: " .. command, 2, vim.fn.exists(":" .. command))
end

-- Public helpers are callable and degrade outside a project.
check("not in Doodba", nil, require("odoo-ide.doodba").find_root())
check("not an Odoo project", false, odoo_ide.context.is_odoo_project())
check("context fields", "table", type(odoo_ide.context.get_context()))

print("")
if failures == 0 then
  print("=== All smoke tests passed ===")
else
  print("=== " .. failures .. " smoke test(s) failed ===")
  os.exit(1)
end
