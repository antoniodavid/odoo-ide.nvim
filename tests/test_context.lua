-- Portable regression tests for context detection.
--
-- Every fixture is created in a temporary directory, so the suite runs on any
-- machine and never depends on a real Odoo checkout.
--
-- Run with: nvim --headless -u NONE -l tests/test_context.lua

local script = debug.getinfo(1, "S").source:sub(2)
local plugin_root = vim.fn.fnamemodify(script, ":p:h:h")
vim.opt.rtp:prepend(plugin_root)

local context = require("odoo-ide.context")

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

local function edit(path)
  vim.cmd("edit " .. vim.fn.fnameescape(path))
end

-- The version cache is process-wide and keyed by directory, so clear it
-- between fixtures to make each scenario independent of the previous one.
local function reset_cache()
  context._cache.version = nil
  context._cache.manifest_path = nil
  context._cache.dir = nil
  context._cache.last_check = 0
end

local base = vim.fn.fnamemodify(vim.fn.tempname(), ":p:h") .. "/odoo-ide-context-test"
vim.fn.delete(base, "rf")

local addon = base .. "/addons/test_addon"
local model_file = addon .. "/models/test_model.py"

write_file(addon .. "/__manifest__.py", "{'name': 'test_addon', 'version': '16.0.1.0.0'}\n")
write_file(
  model_file,
  table.concat({
    "from odoo import api, fields, models",
    "",
    "",
    "class TestModel(models.Model):",
    '    _name = "test.model"',
    '    _description = "Test Model"',
    '    _inherit = "mail.thread"',
    "",
    '    name = fields.Char(string="Name")',
    '    amount = fields.Float(compute="_compute_amount")',
    '    z_orphan = fields.Float(compute="_compute_z_orphan")',
    '    total = fields.Float(compute="_compute_total")',
    "",
    '    @api.depends("name")',
    "    def _compute_amount(self):",
    "        for record in self:",
    "            record.amount = 0.0",
    "",
  }, "\n")
)

-- Manifest discovery and version detection.
edit(model_file)
check("manifest discovery", addon .. "/__manifest__.py", context.find_manifest())
check("addon root", addon, context.get_addon_root())
check("Odoo version", 16, context.get_odoo_version())
check("is Odoo project", true, context.is_odoo_project())

-- File location classification.
local locations = {
  { "models/other_model.py", "models" },
  { "wizards/test_wizard.py", "wizards" },
  { "controllers/main.py", "controllers" },
  { "tests/test_flow.py", "tests" },
  { "views/test_model_views.xml", "views" },
  { "security/ir.model.access.csv", "security" },
  { "data/test_data.xml", "data" },
  { "demo/test_demo.xml", "demo" },
  { "reports/test_report.xml", "reports" },
  { "static/src/js/test.js", "static" },
  { "__manifest__.py", "other" },
  { "README.rst", "other" },
}

for _, case in ipairs(locations) do
  local path = addon .. "/" .. case[1]
  write_file(path, "\n")
  edit(path)
  check("file location: " .. case[1], case[2], context.get_file_location())
end

-- Model introspection.
edit(model_file)
local info = context.get_model_info()
check("model name", "test.model", info.name)
check("model inherit", "mail.thread", info.inherit)
check("model type", "Model", info.type)
check("model field count", 4, #info.fields)
check("model has compute", true, context.has_compute_method("amount"))
check("model missing compute", false, context.has_compute_method("total"))

local orphans = context.find_orphan_computes()
check("orphan compute count", 2, #orphans)
if orphans[1] then
  check("orphan computes are sorted (first)", "total", orphans[1].field)
  check("orphan compute method", "_compute_total", orphans[1].method)
end
if orphans[2] then
  check("orphan computes are sorted (second)", "z_orphan", orphans[2].field)
end

-- Fields declared after the old 200-line cutoff must still be detected.
local large_file = addon .. "/models/large_model.py"
local large_lines = {
  "from odoo import fields, models",
  "",
  "",
  "class LargeModel(models.Model):",
  '    _name = "large.model"',
  "",
}
for index = 1, 240 do
  large_lines[#large_lines + 1] = "    field_" .. index .. " = fields.Char()"
end
large_lines[#large_lines + 1] = '    late_field = fields.Char()'
write_file(large_file, table.concat(large_lines, "\n"))
edit(large_file)
check("model scan covers the whole buffer", true, vim.tbl_contains(context.get_fields(), "late_field"))

-- Directory and URI buffers are not files inside an addon.
vim.cmd("enew")
vim.api.nvim_buf_set_name(0, addon .. "/models")
check("directory buffer location", "other", context.get_file_location())

vim.cmd("enew")
vim.api.nvim_buf_set_name(0, "oil://" .. addon .. "/")
check("URI buffer location", "other", context.get_file_location())

-- A wizard in the same addon reports its own model type.
local wizard_file = addon .. "/wizards/test_wizard.py"
write_file(
  wizard_file,
  table.concat({
    "from odoo import fields, models",
    "",
    "",
    "class TestWizard(models.TransientModel):",
    '    _name = "test.wizard"',
    "",
    '    name = fields.Char()',
    "",
  }, "\n")
)
edit(wizard_file)
check("wizard model type", "TransientModel", context.get_model_info().type)

-- A second project with a different version must not reuse the previous cache.
local other_addon = base .. "/addons/other_addon"
write_file(other_addon .. "/__manifest__.py", "{'name': 'other_addon', 'version': '18.0.2.0.0'}\n")
write_file(other_addon .. "/models/other.py", "from odoo import models\n")
edit(other_addon .. "/models/other.py")
reset_cache()
check("Odoo version after project switch", 18, context.get_odoo_version())

-- Outside any addon the context degrades gracefully instead of erroring.
local plain = base .. "/plain"
write_file(plain .. "/notes.txt", "hello\n")
edit(plain .. "/notes.txt")
check("no manifest outside addon", nil, context.find_manifest())
check("not an Odoo project", false, context.is_odoo_project())
check("location outside addon", "other", context.get_file_location())
check("version outside addon", nil, context.get_odoo_version())

vim.fn.delete(base, "rf")

print("")
if failures == 0 then
  print("=== All context tests passed ===")
else
  print("=== " .. failures .. " context test(s) failed ===")
  os.exit(1)
end
