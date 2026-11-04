-- Portable regression tests for odools.toml generation.
--
-- Builds minimal Doodba and local project trees in a temporary directory, so
-- the suite verifies the generated TOML without needing a real project.
--
-- Run with: nvim --headless -u NONE -l tests/test_odools_config.lua

local script = debug.getinfo(1, "S").source:sub(2)
local plugin_root = vim.fn.fnamemodify(script, ":p:h:h")
vim.opt.rtp:prepend(plugin_root)

local doodba = require("odoo-ide.doodba")
local odools = require("odoo-ide.odools")
local project = require("odoo-ide.project")

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

local function read_file(path)
  local fd = io.open(path, "r")
  if not fd then
    return nil
  end
  local content = fd:read("*a")
  fd:close()
  return content
end

local function cd(path)
  vim.cmd("cd " .. vim.fn.fnameescape(path))
  vim.cmd("enew")
  project.reset()
end

local base = vim.fn.fnamemodify(vim.fn.tempname(), ":p:h") .. "/odoo-ide-odools-test"
vim.fn.delete(base, "rf")

-- Isolate the machine: global Odoo configuration (odoo.conf / ~/.odoorc) must
-- not leak into the fixtures.
local original_home = vim.env.HOME
local original_rc = vim.env.ODOO_RC
vim.env.HOME = base .. "/home"
vim.env.ODOO_RC = ""
vim.fn.mkdir(vim.env.HOME, "p")

-- Doodba environment.
local root = base .. "/env"
local src = root .. "/odoo/custom/src"

write_file(root .. "/common.yaml", 'version: "2.4"\n')
write_file(src .. "/odoo/odoo-bin", "\n")
vim.fn.mkdir(src .. "/odoo/addons", "p")
write_file(src .. "/private/test_addon/__manifest__.py", "{'name': 'test_addon', 'version': '17.0.1.0.0'}\n")
write_file(src .. "/oca-repo/sale_addon/__manifest__.py", "{'name': 'sale_addon', 'version': '17.0.1.0.0'}\n")
write_file(src .. "/dot-repo/dot_addon/__manifest__.py", "{'name': 'dot_addon', 'version': '17.0.1.0.0'}\n")
write_file(src .. "/nested-repo/nested_addon/__manifest__.py", "{'name': 'nested_addon', 'version': '17.0.1.0.0'}\n")
-- Flat, `./`-prefixed and the documented nested format must all be read.
write_file(
  src .. "/addons.yaml",
  table.concat({
    'oca-repo:',
    '  - "*"',
    './dot-repo:',
    '  - "*"',
    './nested-repo:',
    '  defaults:',
    '    depth: 1',
    '  target: odoo 17.0',
    '  merges:',
    '    - odoo 17.0',
    '/missing-repo:',
    '  - "*"',
    '',
  }, "\n")
)
-- Repositories with no modules must not be added.
vim.fn.mkdir(src .. "/empty-repo", "p")

cd(root)

check("Doodba root", root, doodba.find_root())
check("Doodba detected", true, doodba.is_doodba())

local paths = doodba.get_paths()
local seen = {}
for _, path in ipairs(paths) do
  seen[path] = true
end
check_true("paths: odoo core addons", seen[src .. "/odoo/addons"])
check_true("paths: private modules", seen[src .. "/private"])
check_true("paths: repo from addons.yaml", seen[src .. "/oca-repo"])
check_true("paths: dot-prefixed repo", seen[src .. "/dot-repo"])
check_true("paths: nested-format repo", seen[src .. "/nested-repo"])
check_true("paths: missing repo ignored", not seen[src .. "/missing-repo"])
check_true("paths: empty repo excluded", not seen[src .. "/empty-repo"])

local content, err = odools.generate_config({ profile_name = "main" })
check("generate_config error", nil, err)
check_true("generated content", type(content) == "string", content)
content = content or ""

check_true("toml: config table", content:find("%[%[config%]%]") ~= nil)
check_true("toml: profile name", content:find('name = "main"') ~= nil)
check_true("toml: relative odoo path", content:find('odoo_path = "./odoo/custom/src/odoo"', 1, true) ~= nil)
check_true("toml: relative addons paths", content:find('"./odoo/custom/src/private"', 1, true) ~= nil)
check_true("toml: addons.yaml repo included", content:find('"./odoo/custom/src/oca-repo"', 1, true) ~= nil)
check_true("toml: no absolute paths", content:find('"/', 1, true) == nil, content)
check_true("toml: no double slashes", content:find("//", 1, true) == nil, content)
check_true("toml: no unsupported keys", content:find("refresh_mode", 1, true) == nil, content)

local ok, written, changed = odools.write_config({})
check("write_config status", true, ok)
check("write_config path", root .. "/odools.toml", written)
check("write_config changed", true, changed)
check("config on disk", 1, vim.fn.filereadable(root .. "/odools.toml"))
check("config lookup", root .. "/odools.toml", odools.get_config_path())

-- Identical content must not be written again.
local again, second_path, second_changed = odools.write_config({})
check("write_config second status", true, again)
check("write_config second path", root .. "/odools.toml", second_path)
check("write_config is idempotent", false, second_changed)

-- Stale content is regenerated.
write_file(root .. "/odools.toml", "# stale\n")
local _, _, stale_changed = odools.write_config({})
check("write_config regenerates stale content", true, stale_changed)
check_true(
  "write_config restored the profile",
  (read_file(root .. "/odools.toml") or ""):find("%[%[config%]%]") ~= nil
)

-- Local Odoo checkout.
local checkout = base .. "/checkout"
write_file(checkout .. "/odoo-bin", "#!/usr/bin/env python3\n")
write_file(checkout .. "/odoo/release.py", "version_info = (18, 0, 0, 'final', 0, '', 0)\n")
vim.fn.mkdir(checkout .. "/addons", "p")
vim.fn.mkdir(checkout .. "/odoo/addons", "p")
write_file(checkout .. "/my_module/__manifest__.py", "{'name': 'my_module'}\n")

cd(checkout .. "/my_module")

local local_content, local_err = odools.generate_config({})
check("local: generate_config error", nil, local_err)
local_content = local_content or ""
check_true("local: config table", local_content:find("%[%[config%]%]") ~= nil)
check_true("local: odoo path at project root", local_content:find('odoo_path = "./"', 1, true) ~= nil)
check_true("local: addons path", local_content:find('"./addons"', 1, true) ~= nil)
check_true("local: core addons path", local_content:find('"./odoo/addons"', 1, true) ~= nil)

-- Generated files must land in the working repository, never in the Odoo
-- checkout the user cloned.
local local_ok, local_written, local_changed = odools.write_config({})
check("local: write_config status", true, local_ok)
check("local: write_config path", checkout .. "/my_module/odools.toml", local_written)
check("local: write_config changed", true, local_changed)
check("local: config lookup follows the working directory", checkout .. "/my_module/odools.toml", odools.get_config_path())
check("local: checkout root untouched", 0, vim.fn.filereadable(checkout .. "/odools.toml"))

-- Outside any Odoo project the module must refuse instead of writing anywhere.
local plain = base .. "/plain"
vim.fn.mkdir(plain .. "/odoo/custom/src", "p")
cd(plain)

local no_content, no_err = odools.generate_config({})
check("outside project content", nil, no_content)
check("outside project error", "Not in an Odoo project", no_err)

vim.cmd("cd /")
vim.fn.delete(base, "rf")
vim.env.HOME = original_home
vim.env.ODOO_RC = original_rc or ""

print("")
if failures == 0 then
  print("=== All odools config tests passed ===")
else
  print("=== " .. failures .. " odools config test(s) failed ===")
  os.exit(1)
end
