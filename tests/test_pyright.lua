-- Portable tests for pyrightconfig.json generation.
--
-- Run with: nvim --headless -u NONE -l tests/test_pyright.lua

local script = debug.getinfo(1, "S").source:sub(2)
local plugin_root = vim.fn.fnamemodify(script, ":p:h:h")
vim.opt.rtp:prepend(plugin_root)

local project = require("odoo-ide.project")
local pyright = require("odoo-ide.pyright")

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

local function write_file(path, content)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local fd = assert(io.open(path, "w"))
  fd:write(content)
  fd:close()
end

local base = vim.fn.fnamemodify(vim.fn.tempname(), ":p:h") .. "/odoo-ide-pyright-test"
vim.fn.delete(base, "rf")

local original_home = vim.env.HOME
local original_rc = vim.env.ODOO_RC
vim.env.HOME = base .. "/home"
vim.env.ODOO_RC = ""
vim.fn.mkdir(vim.env.HOME, "p")

local root = base .. "/env"
write_file(root .. "/common.yaml", 'version: "2.4"\n')
write_file(root .. "/odoo/custom/src/odoo/odoo-bin", "\n")
write_file(root .. "/odoo/custom/src/private/mod/__manifest__.py", "{'name': 'mod'}\n")

vim.cmd("cd " .. vim.fn.fnameescape(root))
vim.cmd("enew")
project.reset()

local current = project.get()
check_true("project detected", current ~= nil)

local content, err = pyright.generate_config({ project = current })
check("generate error", nil, err)
check_true("generated content", type(content) == "string", content)

local decoded = vim.json.decode(content or "{}")
check("pythonVersion default", "3.10", decoded.pythonVersion)
check("execution root", ".", decoded.executionEnvironments and decoded.executionEnvironments[1].root)
check_true(
  "extraPaths relative",
  decoded.executionEnvironments
    and vim.tbl_contains(decoded.executionEnvironments[1].extraPaths, "./odoo/custom/src/private")
)
check_true("include list", decoded.include and #decoded.include > 0)
check_true("pycache excluded", decoded.exclude and vim.tbl_contains(decoded.exclude, "**/__pycache__"))

local custom = vim.json.decode((pyright.generate_config({ project = current, python_version = "3.12" })))
check("pythonVersion override", "3.12", custom.pythonVersion)

-- Writes into the Doodba root, and only when the content changes.
local ok, written, changed = pyright.write_config({ project = current })
check("write status", true, ok)
check("write path", root .. "/pyrightconfig.json", written)
check("write changed", true, changed)
check("config on disk", 1, vim.fn.filereadable(root .. "/pyrightconfig.json"))

local again, second_path, second_changed = pyright.write_config({ project = current })
check("write again status", true, again)
check("write again path", root .. "/pyrightconfig.json", second_path)
check("write is idempotent", false, second_changed)

-- Outside an Odoo project the module refuses.
vim.cmd("cd /")
vim.cmd("enew")
project.reset()
local none, none_err = pyright.generate_config({})
check("outside project content", nil, none)
check("outside project error", "Not in an Odoo project", none_err)

vim.fn.delete(base, "rf")
vim.env.HOME = original_home
vim.env.ODOO_RC = original_rc or ""

print("")
if failures == 0 then
  print("=== All pyright tests passed ===")
else
  print("=== " .. failures .. " pyright test(s) failed ===")
  os.exit(1)
end
