-- Regression tests for Doodba root detection.
-- Run with: nvim --headless -u NONE -l tests/test_doodba_root.lua

local script = debug.getinfo(1, "S").source:sub(2)
local plugin_root = vim.fn.fnamemodify(script, ":p:h:h")
vim.opt.rtp:prepend(plugin_root)

local doodba = require("odoo-ide.doodba")
local context = require("odoo-ide.context")
local utils = require("odoo-ide.utils")

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

local function write_file(path, content)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local fd = assert(io.open(path, "w"))
  fd:write(content)
  fd:close()
end

local base = vim.fn.fnamemodify(vim.fn.tempname(), ":p:h") .. "/odoo-ide-doodba-test"
vim.fn.delete(base, "rf")

local root = base .. "/env"
local addon_dir = root .. "/odoo/custom/src/private/test_addon"
local model_file = addon_dir .. "/models/test_model.py"

write_file(root .. "/common.yaml", "odoo_projects_dir: odoo/custom/src\n")
write_file(addon_dir .. "/__manifest__.py", "{'name': 'test_addon', 'version': '16.0.1.0.0'}\n")
write_file(model_file, "from odoo import models\n")

-- Regular file buffer inside a Doodba tree.
vim.cmd("edit " .. vim.fn.fnameescape(model_file))
check("regular file: current dir", addon_dir .. "/models", utils.get_current_dir())
check("regular file: Doodba root", root, doodba.find_root())
check("regular file: Doodba detected", true, doodba.is_doodba())
check("regular file: manifest", addon_dir .. "/__manifest__.py", context.find_manifest())
check("regular file: Odoo version", 16, context.get_odoo_version())

-- oil.nvim buffer: `nvim .` names the buffer with an oil:// URI.
local oil_uri = "oil://" .. addon_dir .. "/"
vim.cmd("enew")
vim.api.nvim_buf_set_name(0, oil_uri)
check("oil buffer: current dir", addon_dir, utils.get_current_dir())
check("oil buffer: Doodba root", root, doodba.find_root())
check("oil buffer: Doodba detected", true, doodba.is_doodba())
check("oil buffer: manifest", addon_dir .. "/__manifest__.py", context.find_manifest())

-- Directory buffer without a URI scheme (netrw-style).
vim.cmd("enew")
vim.api.nvim_buf_set_name(0, addon_dir)
check("directory buffer: current dir", addon_dir, utils.get_current_dir())
check("directory buffer: Doodba root", root, doodba.find_root())

-- Unnamed buffer (dashboard): fall back to the working directory.
vim.cmd("enew")
vim.cmd("cd " .. vim.fn.fnameescape(addon_dir))
check("unnamed buffer: current dir", addon_dir, utils.get_current_dir())
check("unnamed buffer: Doodba root", root, doodba.find_root())

-- Outside any Doodba environment.
local outside = base .. "/plain-project"
vim.fn.mkdir(outside, "p")
write_file(outside .. "/main.py", "print('hello')\n")
vim.cmd("enew")
vim.cmd("cd " .. vim.fn.fnameescape(outside))
check("outside Doodba: Doodba root", nil, doodba.find_root())

vim.fn.delete(base, "rf")

print("")
if failures == 0 then
  print("=== All Doodba root tests passed ===")
else
  print("=== " .. failures .. " test(s) failed ===")
  os.exit(1)
end
